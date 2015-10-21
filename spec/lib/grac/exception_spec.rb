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
  end

  it "creates an exception object from a JSON response" do
    exception = described_class.new('GET', 'http://localhost', @body.to_json)
    expect(exception.body).to eq(@body)
    expect(exception.message).to eq("GET 'http://localhost' failed: #{@body}")
    expect(exception.url).to eq("http://localhost")
  end

  it "does not fail if method is nil" do
    exception = described_class.new(nil, 'http://localhost', @body.to_json)
    expect(exception.message).to eq(" 'http://localhost' failed: #{@body}")
  end

  context '#inspect' do
    it "returns a certain string" do
      exception = described_class.new('GET', 'http://localhost', @body.to_json)
      str = "Grac::Exception::ClientException: GET 'http://localhost' failed: #{@body}"
      expect(exception.inspect).to eq(str)
    end
  end

  context '#message' do
    it "returns the message" do
      expect(
        described_class.new('GET', 'http://localhost', @body.to_json).message
      ).to eq("GET 'http://localhost' failed: #{@body}")
    end
  end

  context '#to_s' do
    it "aliases message" do
      expect(
        described_class.new('GET', 'http://localhost', @body.to_json).to_s
      ).to eq("GET 'http://localhost' failed: #{@body}")
    end
  end

  it "provides certain subclasses" do
    expect(Grac::Exception::BadRequest.superclass).to eq(described_class)
    expect(Grac::Exception::Forbidden.superclass).to eq(described_class)
    expect(Grac::Exception::NotFound.superclass).to eq(described_class)
    expect(Grac::Exception::Conflict.superclass).to eq(described_class)
    expect(Grac::Exception::ServiceError.superclass).to eq(described_class)
    expect(Grac::Exception::RequestFailed.superclass).to eq(StandardError)
    expect(Grac::Exception::ServiceTimeout.superclass).to eq(Grac::Exception::RequestFailed)
  end

  context "RequestFailed" do
    it "does not parse the body" do
      exception = Grac::Exception::RequestFailed.new('put', 'http://example.com', 'something<>')
      expect(exception.message).to eq("PUT 'http://example.com' failed: something<>")
    end
  end

  context "ServiceTimeout" do
    it "has a custom message" do
      exception = Grac::Exception::ServiceTimeout.new('put', 'http://example.com', 'something<>')
      expect(exception.message).to eq("PUT 'http://example.com' timed out: something<>")
    end
  end
end
