require 'spec_helper'

describe Grac::Exception::ClientException do
  let(:body) {
    {
      "object" => "resource",
      "error" => "invalid",
      "message" => "resource invalid",
      "errors" => {
        "title" => [{ "error" => "too_long", "count" => 30 }],
        "url"   => [{ "error" => "too_long", "count" => 90 },
                    { "error" => "invalid",  "value" => "asd" }]
      },
    }
  }
  let(:request_method) { 'GET' }
  let(:exception)      { described_class.new(request_method, 'http://localhost', body) }

  it "creates an exception object from a JSON response" do
    expect(exception.body).to eq(body)
    expect(exception.message).to eq("GET 'http://localhost' failed with content: #{body}")
    expect(exception.url).to eq("http://localhost")
  end

  context 'with nil method' do
    let(:request_method) { nil }

    it "does not fail" do
      expect(exception.message).to eq(" 'http://localhost' failed with content: #{body}")
    end
  end

  context '#inspect' do
    it "returns a certain string" do
      str = "Grac::Exception::ClientException: GET 'http://localhost' failed with content: #{body}"
      expect(exception.inspect).to eq(str)
    end
  end

  context '#message' do
    it "returns the message" do
      expect(exception.message).to eq("GET 'http://localhost' failed with content: #{body}")
    end
  end

  context '#to_s' do
    it "aliases message" do
      expect(exception.to_s).to eq("GET 'http://localhost' failed with content: #{body}")
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

  context "InvalidContent" do
    it "has a custom message" do
      exception = Grac::Exception::InvalidContent.new('any body', 'json')
      expect(exception.message).to eq("Failed to parse body as 'json': 'any body'")
      expect(exception.inspect).to eq(
        "Grac::Exception::InvalidContent: Failed to parse body as 'json': 'any body'"
      )
    end
  end
end
