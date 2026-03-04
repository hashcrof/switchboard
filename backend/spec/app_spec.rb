require "spec_helper"
require "rack/test"
require "net/http"
require "rack/handler/puma"
require_relative "../app"

RSpec.describe "App" do
  include Rack::Test::Methods

  let(:payload) do
    {
      "donor": {
        "firstname": "Shreyes",
        "lastname": "Seshasai",
        "addr1": "123 Main St",
        "city": "Washington",
        "state": "DC",
        "zip": "20001",
        "country": "United States",
        "isEligibleForExpressLane": false,
        "employerData": {
          "employer": "Switchboard",
          "occupation": "Engineer",
        },
        "email": "example@example.com",
        "phone": "8885551234"
      },
      "contribution": {
        "createdAt": "2023-06-09T15:59:27-04:00",
        "orderNumber": "AB1111",
        "contributionForm": "sticker103",
        "refcodes": {
          "refcode": "ref-Crane"
        },
        "refcode": "ref-Crane",
        "recurringPeriod": "once",
        "recurringDuration": 1,
        "isRecurring": false,
        "isPaypal": true,
        "isMobile": false,
        "isExpress": false,
        "withExpressLane": false,
        "expressSignup": false,
        "textMessageOption": "opt_in",
        "customFields": [],
        "status": "approved",
      },
      "lineitems": [
        {
          "sequence": 1,
          "entityId": 1,
          "fecId": "C00000",
          "committeeName": "Eric for Dogcatcher",
          "amount": "5.0",
          "paidAt": "2023-08-27T04:59:45-04:00",
          "paymentId": 242184335,
          "lineitemId": 500314606
        }
      ],
      "form": {
        "name": "sticker103",
        "kind": "page",
        "managingEntityName": "Eric for Dogcatcher",
        "managingEntityCommitteeName": "Eric for Dogcatcher"
      }
    }
  end

  let(:payload_no_donor) do
    {
      "contribution": {
        "createdAt": "2023-06-09T15:59:27-04:00",
        "orderNumber": "AB1111",
        "contributionForm": "sticker103",
        "refcodes": {
          "refcode": "ref-Crane"
        },
        "refcode": "ref-Crane",
        "recurringPeriod": "once",
        "recurringDuration": 1,
        "isRecurring": false,
        "isPaypal": true,
        "isMobile": false,
        "isExpress": false,
        "withExpressLane": false,
        "expressSignup": false,
        "textMessageOption": "opt_in",
        "customFields": [],
        "status": "approved",
      },
      "lineitems": [
        {
          "sequence": 1,
          "entityId": 1,
          "fecId": "C00000",
          "committeeName": "Eric for Dogcatcher",
          "amount": "5.0",
          "paidAt": "2023-08-27T04:59:45-04:00",
          "paymentId": 242184335,
          "lineitemId": 500314606
        }
      ],
      "form": {
        "name": "sticker103",
        "kind": "page",
        "managingEntityName": "Eric for Dogcatcher",
        "managingEntityCommitteeName": "Eric for Dogcatcher"
      }
    }
  end

  let(:payload_no_contribution) do
    {
      "donor": {
        "firstname": "Shreyes",
        "lastname": "Seshasai",
        "addr1": "123 Main St",
        "city": "Washington",
        "state": "DC",
        "zip": "20001",
        "country": "United States",
        "isEligibleForExpressLane": false,
        "employerData": {
          "employer": "Switchboard",
          "occupation": "Engineer",
        },
        "email": "example@example.com",
        "phone": "8885551234"
      },
      "lineitems": [
        {
          "sequence": 1,
          "entityId": 1,
          "fecId": "C00000",
          "committeeName": "Eric for Dogcatcher",
          "amount": "5.0",
          "paidAt": "2023-08-27T04:59:45-04:00",
          "paymentId": 242184335,
          "lineitemId": 500314606
        }
      ],
      "form": {
        "name": "sticker103",
        "kind": "page",
        "managingEntityName": "Eric for Dogcatcher",
        "managingEntityCommitteeName": "Eric for Dogcatcher"
      }
    }
  end

  let(:payload_no_line_items) do
    {
      "donor": {
        "firstname": "Shreyes",
        "lastname": "Seshasai",
        "addr1": "123 Main St",
        "city": "Washington",
        "state": "DC",
        "zip": "20001",
        "country": "United States",
        "isEligibleForExpressLane": false,
        "employerData": {
          "employer": "Switchboard",
          "occupation": "Engineer",
        },
        "email": "example@example.com",
        "phone": "8885551234"
      },
      "contribution": {
        "createdAt": "2023-06-09T15:59:27-04:00",
        "orderNumber": "AB1113",
        "contributionForm": "sticker103",
        "refcodes": {
          "refcode": "ref-Crane"
        },
        "refcode": "ref-Crane",
        "recurringPeriod": "once",
        "recurringDuration": 1,
        "isRecurring": false,
        "isPaypal": true,
        "isMobile": false,
        "isExpress": false,
        "withExpressLane": false,
        "expressSignup": false,
        "textMessageOption": "opt_in",
        "customFields": [],
        "status": "approved",
      },
      "lineitems": [],
      "form": {
        "name": "sticker103",
        "kind": "page",
        "managingEntityName": "Eric for Dogcatcher",
        "managingEntityCommitteeName": "Eric for Dogcatcher"
      }
    }
  end

  def app
    Sinatra::Application
  end

  before do
    header "Host", "localhost"
    ENV["AUTH_USER"] = "testuser"
    ENV["AUTH_PASSWORD"] = "testpass"
    ENV["TOKEN_SECRET"] = "testsecret"
  end

  it "returns status ok" do
    get "/health"

    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq({"status" => "ok"})
  end

  it "is not authorized for wrong credentials" do
    authorize "wronguser", "wrongpass"
    post "/webhook/actblue_donation"

    expect(last_response.status).to eq(401)
    expect(JSON.parse(last_response.body)).to eq({"error" => "Not Authorized"})
  end

  it "is not authorized for empty credentials" do
    post "/webhook/actblue_donation"

    expect(last_response.status).to eq(401)
    expect(JSON.parse(last_response.body)).to eq({"error" => "Not Authorized"})
  end

  it "returns error invalid payload when  payload is empty" do
    authorize "testuser", "testpass"
    post "/webhook/actblue_donation"

    expect(last_response.status).to eq(400)
    expect(JSON.parse(last_response.body)).to eq({"error" => "Invalid payload"})
  end

  it "returns status received when authorized with valid payload" do
    authorize "testuser", "testpass"
    post "/webhook/actblue_donation", payload.to_json, "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq({"status" => "received"})
  end

  it "returns already processed for duplicate payload" do
    authorize "testuser", "testpass"
    post "/webhook/actblue_donation", payload.to_json, "CONTENT_TYPE" => "application/json"
    post "/webhook/actblue_donation", payload.to_json, "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq({"status" => "already_processed"})
  end

  it "returns invalid payload when payload has no line items" do
    authorize "testuser", "testpass"
    post "/webhook/actblue_donation", payload_no_line_items.to_json, "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(400)
    expect(JSON.parse(last_response.body)).to eq({"error" => "Invalid payload"})
  end

  it "returns invalid payload when payload has no contribution" do
    authorize "testuser", "testpass"
    post "/webhook/actblue_donation", payload_no_contribution.to_json, "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(400)
    expect(JSON.parse(last_response.body)).to eq({"error" => "Invalid payload"})
  end

  it "returns invalid payload when payload has no donor" do
    authorize "testuser", "testpass"
    post "/webhook/actblue_donation", payload_no_donor.to_json, "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(400)
    expect(JSON.parse(last_response.body)).to eq({"error" => "Invalid payload"})
  end

  it "returns invalid payload when payload is malformed or not valid JSON" do
    authorize "testuser", "testpass"
    post "/webhook/actblue_donation", '', "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(400)
    expect(JSON.parse(last_response.body)).to eq({"error" => "Invalid payload"})
  end

  describe "real HTTP client " do
    let(:sse_payload) do
      {
        "donor": {
          "firstname": "Shreyes",
          "lastname": "Seshasai",
          "addr1": "123 Main St",
          "city": "Washington",
          "state": "DC",
          "zip": "20001",
          "country": "United States",
          "isEligibleForExpressLane": false,
          "employerData": {
            "employer": "Switchboard",
            "occupation": "Engineer",
          },
          "email": "example@example.com",
          "phone": "8885551234"
        },
        "contribution": {
          "createdAt": "2023-06-09T15:59:27-04:00",
          "orderNumber": "AB1114",
          "contributionForm": "sticker103",
          "refcodes": {
            "refcode": "ref-Crane"
          },
          "refcode": "ref-Crane",
          "recurringPeriod": "once",
          "recurringDuration": 1,
          "isRecurring": false,
          "isPaypal": true,
          "isMobile": false,
          "isExpress": false,
          "withExpressLane": false,
          "expressSignup": false,
          "textMessageOption": "opt_in",
          "customFields": [],
          "status": "approved",
        },
        "lineitems": [
          {
            "sequence": 1,
            "entityId": 1,
            "fecId": "C00000",
            "committeeName": "Eric for Dogcatcher",
            "amount": "5.0",
            "paidAt": "2023-08-27T04:59:45-04:00",
            "paymentId": 242184335,
            "lineitemId": 500314607
          }
        ],
        "form": {
          "name": "sticker103",
          "kind": "page",
          "managingEntityName": "Eric for Dogcatcher",
          "managingEntityCommitteeName": "Eric for Dogcatcher"
        }
      }
    end

    before(:context) do
      @thread = Thread.new do
        Rack::Handler::Puma.run(app, Port: 9877, Silent: true)
      end
      sleep(2)
    end

    it 'receives donation data over a live stream' do
      encoded = Base64.strict_encode64("testuser:testpass")
      token_response = Net::HTTP.get_response(URI("http://localhost:9877/stream/token"), "Authorization" => "Basic #{encoded}")
      token = JSON.parse(token_response.body)["token"]

      ready = Queue.new
      data = []
      sse_client_thr = Thread.new do
        Net::HTTP.start("localhost", 9877) do |http|
          request = Net::HTTP::Get.new("/stream?token=#{token}")
          http.request(request) do |response|
            ready.push(:ready)
            response.read_body do |chunk|
              next if chunk.include?("heartbeat")
              data << chunk
              break if chunk.include?("data")
            end
          end
        end
      end

      ready.pop
      response = Net::HTTP.post(
        URI("http://localhost:9877/webhook/actblue_donation"),
        sse_payload.to_json,
        "Content-Type" => "application/json",
        "Authorization" => "Basic #{encoded}"
      )
      sse_client_thr.join(5)

      data.each do |d|
        expected_data = {id:"AB1114",firstname:"Shreyes",lastname:"Seshasai",email:"example@example.com",amount:5,refcode:"ref-Crane",timestamp:"2023-06-09T15:59:27-04:00",recurring:false}
        expect(d.force_encoding("UTF-8")).to eq("data: #{expected_data.to_json}\n\n")
      end
      expect(JSON.parse(response.body)).to eq({"status" => "received"})
    end

    after(:context) do
      @thread.kill
    end
  end
end
