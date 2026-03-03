require "sinatra"
require "json"
require "dotenv/load"
require "set"
require_relative "lib/actblue"

set :server, :puma
set :bind, 'localhost'
set :port, ENV["PORT"] || 8000
set :connections, Set.new

PROCESSED_ORDERS = Set.new


before do
  headers \
    "Access-Control-Allow-Origin"  => "http://localhost:5173",
    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers" => "Content-Type"
end

helpers do
  def authorized?
    auth = Rack::Auth::Basic::Request.new(request.env)
    auth.provided? &&
      auth.basic? &&
      auth.credentials == [ENV["AUTH_USER"], ENV["AUTH_PASSWORD"]]
  end

  def protected!
    return if authorized?
    halt 401, { error: "Not Authorized" }.to_json
  end
end

get "/health" do
  content_type :json
  { status: "ok" }.to_json
end

get '/stream', provides: 'text/event-stream' do
  stream :keep_open do |out|
    if settings.connections.add?(out)
      puts "OPEN  — #{settings.connections.size} connections"
      out.callback {
        settings.connections.delete(out)
        puts "CLOSE — #{settings.connections.size} connections"
      }
    end
    out << "heartbeat:\n"
    sleep 1
  rescue
    out.close
  end
end

post "/webhook/actblue_donation" do
  content_type :json
  protected!
  payload = JSON.parse(request.body.read) rescue nil

  halt 400, { error: "Invalid payload" }.to_json unless payload
  #puts payload.inspect

  donor = payload["donor"]
  contribution = payload["contribution"]
  line_item = payload["lineitems"][0]

  halt 400, { error: "Invalid payload" }.to_json unless donor and contribution and line_item

  idempotency_key = ActBlue.idempotency_key(contribution["orderNumber"], line_item["paidAt"], line_item["lineitemId"])

  if PROCESSED_ORDERS.include? idempotency_key
    puts "Duplicate webhook received for order #{contribution["orderNumber"]} paid at #{line_item["paidAt"]} with line item id #{line_item["lineitemId"]}, skipping"
    return { status: "already_processed" }.to_json
  end

  PROCESSED_ORDERS << idempotency_key

  donation = {
    id:        contribution["orderNumber"],
    firstname: donor["firstname"],
    lastname:  donor["lastname"],
    email:     donor["email"],
    amount:    line_item["amount"].to_f.round,
    refcode:   contribution["refcode"],
    timestamp: contribution["createdAt"] || Time.now.iso8601,
    recurring: !payload["recurringPeriod"].nil?,
  }

  settings.connections.each do |out|
    out << "data: #{donation.to_json}\n\n"
  rescue
    puts "Closing connection: #{out}"
    out.close
  end
  puts "Donation #{contribution["orderNumber"]} broadcast to #{settings.connections.size} client(s)"
  status 200
  { status: "received" }.to_json
end