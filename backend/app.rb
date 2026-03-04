require "sinatra"
require "json"
require "dotenv/load"
require "concurrent"
require "openssl"
require "redis"
require_relative "lib/actblue"

set :server, :puma
set :bind, 'localhost'
set :port, ENV["PORT"] || 8000
set :connections, Concurrent::Set.new

REDIS      = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
SUBSCRIBER = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))

Thread.new do
  SUBSCRIBER.subscribe("donations") do |on|
    on.message do |_channel, message|
      Sinatra::Application.settings.connections.each do |out|
        out << "data: #{message}\n\n"
      rescue
        out.close
      end
    end
  end
end

trap("INT") do
  SUBSCRIBER.unsubscribe
  Sinatra::Application.settings.connections.each(&:close)
  raise Interrupt
end

before do
  headers \
    "Access-Control-Allow-Origin"  => "http://localhost:5173",
    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers" => "Content-Type, Authorization"
end

options "*" do
  200
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

  def generate_stream_token
    OpenSSL::HMAC.hexdigest("SHA256", ENV["TOKEN_SECRET"], Time.now.to_i.to_s)
  end

  def valid_stream_token?(token)
    return false if token.nil?
    (0..60).any? do |offset|
      expected = OpenSSL::HMAC.hexdigest("SHA256", ENV["TOKEN_SECRET"], (Time.now.to_i - offset).to_s)
      Rack::Utils.secure_compare(expected, token)
    end
  end
end

get "/health" do
  content_type :json
  { status: "ok" }.to_json
end

get '/stream/token' do
  protected!
  content_type :json
  { token: generate_stream_token }.to_json
end

get '/stream', provides: 'text/event-stream' do
  halt 401, { error: "Not Authorized" }.to_json unless valid_stream_token?(params[:token])
  stream :keep_open do |out|
    if settings.connections.add?(out)
      puts "OPEN  — #{settings.connections.size} connections"
      out.callback {
        settings.connections.delete(out)
        puts "CLOSE — #{settings.connections.size} connections"
      }
    end
    out << ": heartbeat\n\n"
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

  unless REDIS.set(idempotency_key, "1", nx: true, ex: 86_400)
    puts "Duplicate webhook received for order #{contribution["orderNumber"]} paid at #{line_item["paidAt"]} with line item id #{line_item["lineitemId"]}, skipping"
    return { status: "already_processed" }.to_json
  end

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

  REDIS.publish("donations", donation.to_json)
  puts "Donation #{contribution["orderNumber"]} broadcast to #{settings.connections.size} client(s)"
  status 200
  { status: "received" }.to_json
end