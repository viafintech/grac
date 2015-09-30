# encoding: UTF-8
require 'spec_helper'

describe Grac::Client do
  let(:grac) { described_class.new }

  def check_options(client, field, value)
    expect(client.instance_variable_get("@options")[field]).to eq(value)
  end

  context "#initialize" do
    it "initializes the client with default values" do
      client = described_class.new
      expect(client.instance_variable_get("@options")).to eq({
        "scheme"         => "http",
        "host"           => "localhost",
        "port"           => 80,
        "path"           => "/",
        "connecttimeout" => 0.1,
        "timeout"        => 15,
        "params"         => {},
        "headers"        => { "User-Agent" => "Grac v#{Grac::VERSION}" }
      })
    end

    it "allows setting scheme, host, port and path with the uri setting" do
      client = described_class.new("uri" => "https://host:1234/path")
      expect(client.instance_variable_get("@options")).to eq({
        "scheme"         => "https",
        "host"           => "host",
        "port"           => 1234,
        "path"           => "/path",
        "connecttimeout" => 0.1,
        "timeout"        => 15,
        "params"         => {},
        "headers"        => { "User-Agent" => "Grac v#{Grac::VERSION}" }
      })
    end

    it "allows setting scheme, host, port and path individually" do
      client = described_class.new(
        "scheme" => "https",
        "host"   => "example.com",
        "port"   => 5678,
        "path"   => "blub"
      )
      expect(client.instance_variable_get("@options")).to eq({
        "scheme"         => "https",
        "host"           => "example.com",
        "port"           => 5678,
        "path"           => "/blub",
        "connecttimeout" => 0.1,
        "timeout"        => 15,
        "params"         => {},
        "headers"        => { "User-Agent" => "Grac v#{Grac::VERSION}" }
      })
    end

    {
      "connecttimeout" => 0.4,
      "timeout"        => 10,
      "params"         => { "abc" => "def" },
      "headers"        => { "User-Agent" => "Test" }
    }.each do |param, value|
      it "allows setting the #{param}" do
        client = described_class.new(param => value)
        check_options(client, param, value)
      end
    end

    it "keeps the user_agent header if it is not overwritten" do
      client = described_class.new("headers" => { "Request-Id" => "123234234" })
      check_options(client, "headers",
        { "User-Agent" => "Grac v#{Grac::VERSION}", "Request-Id" => "123234234" })
    end
  end

  context "#set" do
    it "sets options and creates a new client instance" do
      new_client = grac.set({ "host" => "example.com" })
      expect(new_client).to_not eq(grac)
      check_options(grac,       "host", "localhost")
      check_options(new_client, "host", "example.com")
    end
  end

  context "#set!" do
    it "sets options on the existing instance" do
      client = grac.set!({ "host" => "example.com" })
      expect(client).to eq(grac)
      check_options(grac,   "host", "example.com")
      check_options(client, "host", "example.com")
    end
  end

  context "#method_missing" do
    it "appends to the path and create a new client instance" do
      check_options(grac, "path", "/")
      client = grac.v1
      expect(client).to_not eq(grac)
      check_options(grac,   "path", "/")
      check_options(client, "path", "/v1")
    end

    it "appends to the path and sets it on the current instance" do
      check_options(grac, "path", "/")
      client = grac.v1!
      expect(client).to eq(grac)
      check_options(grac,   "path", "/v1")
      check_options(client, "path", "/v1")
    end
  end

  context "#respond_to_missing?" do
    it "returns a method for an unknown method" do
      expect(grac.methods.include?(:v1)).to eq(false)
      expect(grac.private_methods.include?(:v1)).to eq(false)
      expect(grac.method(:v1).name).to eq(:v1)
      expect(grac.respond_to?(:v1)).to eq(true)
      expect(grac.respond_to?(:v1, true)).to eq(true)
    end

    it "returns a method for a private method" do
      expect(grac.methods.include?(:build_request)).to eq(false)
      expect(grac.private_methods.include?(:build_request)).to eq(true)
      expect(grac.method(:build_request).name).to eq(:build_request)
      expect(grac.respond_to?(:build_request)).to eq(false)
      expect(grac.respond_to?(:build_request, true)).to eq(true)
    end

    it "returns a method for a public method" do
      expect(grac.methods.include?(:uri)).to eq(true)
      expect(grac.private_methods.include?(:uri)).to eq(false)
      expect(grac.method(:uri).name).to eq(:uri)
      expect(grac.respond_to?(:uri)).to eq(true)
      expect(grac.respond_to?(:uri, true)).to eq(true)
    end
  end

  context "#var" do
    it "appends to the path and create a new client instance" do
      check_options(grac, "path", "/")
      client = grac.var(1)
      expect(client).to_not eq(grac)
      check_options(grac,   "path", "/")
      check_options(client, "path", "/1")
    end
  end

  context "#var!" do
    it "appends to the path and sets it on the current instance" do
      check_options(grac, "path", "/")
      client = grac.var!(1)
      expect(client).to eq(grac)
      check_options(grac,   "path", "/1")
      check_options(client, "path", "/1")
    end
  end

  context "#type" do
    it "appends to the path and create a new client instance" do
      check_options(grac, "path", "/")
      client = grac.var(1).type("pdf")
      expect(client).to_not eq(grac)
      check_options(grac,   "path", "/")
      check_options(client, "path", "/1.pdf")
    end
  end

  context "#type!" do
    it "appends to the path and sets it on the current instance" do
      check_options(grac, "path", "/")
      client = grac.var!(1).type!("pdf")
      expect(client).to eq(grac)
      check_options(grac,   "path", "/1.pdf")
      check_options(client, "path", "/1.pdf")
    end
  end

  context "#expand" do
    it "replaces the template parts in the path and creates a new client instance" do
      grac.set!("path" => "/var/{template}/{another_template}")
      client = grac.expand("template" => "abc")
      expect(client).to_not eq(grac)
      check_options(grac,   "path", "/var/{template}/{another_template}")
      check_options(client, "path", "/var/abc/")
    end
  end

  context "#expand!" do
    it "replaces the template parts in the path and sets the path on the current instance" do
      grac.set!("path" => "/var/{template}/{another_template}")
      client = grac.expand!("template" => "abc")
      expect(client).to eq(grac)
      check_options(grac,   "path", "/var/abc/")
      check_options(client, "path", "/var/abc/")
    end
  end

  context "#partial_expand" do
    it "replaces the template parts in the path and creates a new client instance" do
      grac.set!("path" => "/var/{template}/{another_template}")
      client = grac.partial_expand("template" => "abc")
      expect(client).to_not eq(grac)
      check_options(grac,   "path", "/var/{template}/{another_template}")
      check_options(client, "path", "/var/abc/{another_template}")
    end
  end

  context "#partial_expand!" do
    it "replaces the template parts in the path and sets the path on the current instance" do
      grac.set!("path" => "/var/{template}/{another_template}")
      client = grac.partial_expand!("template" => "abc")
      expect(client).to eq(grac)
      check_options(grac,   "path", "/var/abc/{another_template}")
      check_options(client, "path", "/var/abc/{another_template}")
    end
  end

  context "http methods" do
    %w{post put patch}.each do |method|
      context "##{method}" do
        it "calls build request with body and params" do
          expect(grac).to receive(:build_request)
                      .with(method, { "body" => {}, "params" => {} })
                      .and_return(double = Object.new)
          expect(grac).to receive(:handle_response).with(double).and_return(true)
          expect(grac.send(method)).to eq(true)
        end
      end
    end

    %w{get delete}.each do |method|
      context "##{method}" do
        it "calls build request with params" do
          expect(grac).to receive(:build_request)
                      .with(method, {  "params" => {} })
                      .and_return(double = Object.new)
          expect(grac).to receive(:handle_response).with(double).and_return(true)
          expect(grac.send(method)).to eq(true)
        end
      end
    end
  end

  context "#build_request" do
    it "sets certain values on Typhoeus" do
      expect(Typhoeus::Request).to receive(:new)
                               .with("http://localhost:80/", {
                                  :method  => "get",
                                  :params  => {},
                                  :body    => nil,
                                  :connecttimeout => 0.1,
                                  :timeout => 15,
                                  :headers => { "User-Agent" => "Grac v#{Grac::VERSION}" }
                                })
      grac.send(:build_request, "get", {})
    end

    it "sets a json body" do
      expect(Typhoeus::Request).to receive(:new)
                               .with("http://localhost:80/", {
                                  :method  => "post",
                                  :params  => {},
                                  :body    => { "abc" => "def" }.to_json,
                                  :connecttimeout => 0.1,
                                  :timeout => 15,
                                  :headers => { "User-Agent" => "Grac v#{Grac::VERSION}" }
                                })
      grac.send(:build_request, "post", { "body" => { "abc" => "def" } })
    end

    it "sets params" do
      expect(Typhoeus::Request).to receive(:new)
                               .with("http://localhost:80/", {
                                  :method  => "post",
                                  :params  => { "abc" => "def" },
                                  :body    => nil,
                                  :connecttimeout => 0.1,
                                  :timeout => 15,
                                  :headers => { "User-Agent" => "Grac v#{Grac::VERSION}" }
                                })
      grac.send(:build_request, "post", { "params" => { "abc" => "def" } })
    end

    it "merges with predefined params" do
      grac.set!("params" => { "example" => "blub" })
      expect(Typhoeus::Request).to receive(:new)
                               .with("http://localhost:80/", {
                                  :method  => "post",
                                  :params  => { "example" => "blub", "abc" => "def" },
                                  :body    => nil,
                                  :connecttimeout => 0.1,
                                  :timeout => 15,
                                  :headers => { "User-Agent" => "Grac v#{Grac::VERSION}" }
                                })
      grac.send(:build_request, "post", { "params" => { "abc" => "def" } })
    end
  end

  context "#handle_response" do
    let(:request) { double('request', 'options' => { "method" => "get" }) }
    let(:response) { double('response', 'timed_out?' => false, 'code' => 200,
                            'body' => { "value" => "success" }.to_json) }

    before do
      expect(request).to receive(:run).and_return(response)
    end

    context "retry" do
      it "retries for get" do
        expect(request).to receive(:run).and_return(response)
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "retries for head" do
        expect(request).to receive(:options).and_return({ "method" => "head" })
        expect(request).to receive(:run).and_return(response)
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "does not retry for post" do
        expect(request).to receive(:options).and_return({ "method" => "post" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "does not retry for put" do
        expect(request).to receive(:options).and_return({ "method" => "put" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "does not retry for patch" do
        expect(request).to receive(:options).and_return({ "method" => "patch" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "does not retry for delete" do
        expect(request).to receive(:options).and_return({ "method" => "delete" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "raises a ServiceTimeout if the response timed out" do
        expect(request).to receive(:options).and_return({ "method" => "put" })
        expect(response).to receive(:timed_out?).twice.and_return(true)
        allow(response).to receive(:return_message).and_return("timeout")
        expect{
          grac.send(:handle_response, request)
        }.to raise_exception(Grac::Exception::ServiceTimeout, "Service timed out: timeout")
      end
    end

    context "response code 200" do
      it "returns a parsed json body" do
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "returns the body as is if it is not valid json" do
        allow(response).to receive(:body).and_return("cookies")
        expect(grac.send(:handle_response, request)).to eq("cookies")
      end
    end

    context "response code 201" do
      before do
        allow(response).to receive(:code).and_return(201)
      end

      it "returns a parsed json body" do
        expect(grac.send(:handle_response, request)).to eq({ "value" => "success" })
      end

      it "returns the body as is if it is not valid json" do
        allow(response).to receive(:body).and_return("cookies")
        expect(grac.send(:handle_response, request)).to eq("cookies")
      end
    end

    context "response code 204" do
      before do
        allow(response).to receive(:code).and_return(204)
      end

      it "returns true" do
        expect(grac.send(:handle_response, request)).to eq(true)
      end
    end

    context "response code 0" do
      before do
        allow(response).to receive(:code).and_return(0)
        allow(response).to receive(:return_message).and_return("timeout")
      end

      it "raises a RequestFailed exception" do
        expect{
          grac.send(:handle_response, request)
        }.to raise_exception(Grac::Exception::RequestFailed, "Service request failed: timeout")
      end
    end

    context "response code 400" do
      it "raises a Invalid exception" do
        allow(response).to receive(:code).and_return(400)
        expect{
          grac.send(:handle_response, request)
        }.to raise_exception(Grac::Exception::Invalid)
      end
    end

    context "response code 403" do
      it "raises a Forbidden exception" do
        allow(response).to receive(:code).and_return(403)
        expect{
          grac.send(:handle_response, request)
        }.to raise_exception(Grac::Exception::Forbidden)
      end
    end

    context "response code 404" do
      it "raises a NotFound exception" do
        allow(response).to receive(:code).and_return(404)
        expect{
          grac.send(:handle_response, request)
        }.to raise_exception(Grac::Exception::NotFound)
      end
    end

    context "response code 409" do
      it "raises a Conflict exception" do
        allow(response).to receive(:code).and_return(409)
        expect{
          grac.send(:handle_response, request)
        }.to raise_exception(Grac::Exception::Conflict)
      end
    end

    context "other response code e.g. 500" do
      it "raises a ServiceError exception" do
        allow(response).to receive(:code).and_return(500)
        expect{
          grac.send(:handle_response, request)
        }.to raise_exception(Grac::Exception::ServiceError)
      end
    end
  end
end
