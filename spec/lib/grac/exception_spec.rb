# encoding: UTF-8
require 'spec_helper'

describe Grac::Exception::ClientException do
  before(:each) do
    @body = {
      "object" => "resource",
      "error" => "invalid",
      "message" => "resource invalid",
      "errors" => {
        "title" => [{ "error" => "too_long", "count" => 30 }],
        "url"   => [{ "error" => "too_long", "count" => 90 },
                    { "error" => "invalid",  "value" => "asd" }]
      },
    }
    @request = double('request', 'url' => 'http://localhost')
    @response = Typhoeus::Response.new(code: 400, body: @body.to_json)
    allow(@response).to receive(:request).and_return(@request)
  end

  it "creates an exception object from a JSON response" do
    exception = described_class.new(@response)
    expect(exception.http_code).to eq(400)
    expect(exception.service_response).to eq(@body)
    expect(exception.object).to eq(:resource)
    expect(exception.error).to eq(:invalid)
    expect(exception.message).to eq("resource invalid")
    expect(exception.errors).to eq(@body["errors"])
    expect(exception.url).to eq("http://localhost")
  end

  it "works if the error response contains no 'errors' param" do
    @body.delete("errors")
    response = Typhoeus::Response.new(code: 400, body: @body.to_json)
    allow(response).to receive(:request).and_return(@request)
    expect(described_class.new(response).errors).to eq({})
  end

  context '#inspect' do
    it "returns a certain string" do
      exception = described_class.new(@response)
      str = "Grac::Exception::ClientException: #{exception.service_response}"
      expect(exception.inspect).to eq(str)
    end
  end

  context '#to_s' do
    it "returns the message if the error response contains one" do
      expect(described_class.new(@response).to_s).to eq("resource invalid")
    end

    it "returns the class name if the error response does not contain a message" do
      @body.delete("message")
      response = Typhoeus::Response.new(code: 400, body: @body.to_json)
      allow(response).to receive(:request).and_return(@request)
      expect(described_class.new(response).to_s).to eq("Grac::Exception::ClientException")
    end
  end

  it "provides certain subclasses" do
    expect(Grac::Exception::Invalid.superclass).to eq(described_class)
    expect(Grac::Exception::Forbidden.superclass).to eq(described_class)
    expect(Grac::Exception::NotFound.superclass).to eq(described_class)
    expect(Grac::Exception::Conflict.superclass).to eq(described_class)
    expect(Grac::Exception::ServiceError.superclass).to eq(described_class)
    expect(Grac::Exception::RequestFailed.superclass).to eq(StandardError)
    expect(Grac::Exception::ServiceTimeout.superclass).to eq(Grac::Exception::RequestFailed)
  end
end
