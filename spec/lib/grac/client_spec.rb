# encoding: UTF-8
require 'spec_helper'
require 'bigdecimal'

describe Grac::Client do
  let(:grac) { described_class.new("http://localhost:80") }

  def check_options(client, field, value)
    expect(client.instance_variable_get("@options")[field]).to eq(value)
  end

  context "#initialize" do
    it "initializes the client with default values" do
      client = described_class.new("http://localhost:80")
      expect(client.instance_variable_get("@options")).to eq({
        :connecttimeout => 0.1,
        :timeout        => 15,
        :params         => {},
        :headers        => { "User-Agent" => "Grac v#{Grac::VERSION}" },
        :postprocessing => {}
      })
      expect(client.uri).to eq("http://localhost:80")
    end

    {
      :connecttimeout => 0.4,
      :timeout        => 10,
      :params         => { "abc" => "def" },
      :headers        => { "User-Agent" => "Test" },
      :postprocessing => { "amount" => ->(value){ BigDecimal.new(value.to_s) } }
    }.each do |param, value|
      it "allows setting the #{param}" do
        client = described_class.new("http://localhost:80", param => value)
        check_options(client, param, value)
      end
    end

    it "keeps the user_agent header if it is not overwritten" do
      client = described_class.new("http://localhost", :headers => { "Request-Id" => "123234234" })
      check_options(client, :headers,
        { "User-Agent" => "Grac v#{Grac::VERSION}", "Request-Id" => "123234234" })
    end
  end

  context "#set" do
    it "sets options and creates a new client instance" do
      new_client = grac.set({ :timeout => 30 })
      expect(new_client).to_not eq(grac)
      check_options(grac,       :timeout, 15)
      check_options(new_client, :timeout, 30)
    end
  end

  context "#path" do
    it "appends to the uri and create a new client instance" do
      expect(grac.uri).to eq("http://localhost:80")
      client = grac.path("/v2/transactions")
      expect(client).to_not eq(grac)
      expect(client.uri).to eq("http://localhost:80/v2/transactions")
    end
  end

  context "http methods" do
    %w{post put patch}.each do |method|
      context "##{method}" do
        it "calls build request with body and params" do
          expect(grac).to receive(:build_request)
                      .with(method, { :body => {}, :params => {} })
                      .and_return(double = Object.new)
          expect(grac).to receive(:run).with(double).and_return(true)
          expect(grac.send(method)).to eq(true)
        end
      end
    end

    %w{get delete}.each do |method|
      context "##{method}" do
        it "calls build request with params" do
          expect(grac).to receive(:build_request)
                      .with(method, {  :params => {} })
                      .and_return(double = Object.new)
          expect(grac).to receive(:run).with(double).and_return(true)
          expect(grac.send(method)).to eq(true)
        end
      end
    end
  end

  context "postprocessing" do
    it "does nothing if postprocessing is not set" do
      data = {}
      expect(data).to_not receive(:kind_of?)
      grac.send(:postprocessing, data)
    end

    it "automatically converts a field" do
      data = { "amount" => "123.12", "something_else" => "value" }
      client = grac.set(:postprocessing => { 'amount$' => ->(value){ BigDecimal.new(value) } })
      expect(client.send(:postprocessing, data)).to eq({
        "amount"         => BigDecimal.new("123.12"),
        "something_else" => "value"
      })
    end

    it "automatically converts a value in a nested hash field" do
      data = { "nested" => { "amount" => "123.12" }, "something_else" => "value" }
      client = grac.set(:postprocessing => { 'amount$' => ->(value){ BigDecimal.new(value) } })
      expect(client.send(:postprocessing, data)).to eq({
        "nested" => {
          "amount" => BigDecimal.new("123.12"),
        },
        "something_else" => "value"
      })
    end

    it "automatically converts a value in a nested array field" do
      data = { "nested" => [{ "amount" => "123.12" }], "something_else" => "value" }
      client = grac.set(:postprocessing => { 'amount$' => ->(value){ BigDecimal.new(value) } })
      expect(client.send(:postprocessing, data)).to eq({
        "nested" => [{
          "amount" => BigDecimal.new("123.12"),
        }],
        "something_else" => "value"
      })
    end

    it "automatically converts field values if all of them are in an array" do
      data = { "amount" => ["123.12", "154.23"], "something_else" => "value" }
      client = grac.set(:postprocessing => { 'amount$' => ->(value){ BigDecimal.new(value) } })
      expect(client.send(:postprocessing, data)).to eq({
        "amount" => [BigDecimal.new("123.12"), BigDecimal.new("154.23")],
        "something_else" => "value"
      })
    end

    it "does not convert if the value of key is a nested hash" do
      data = { "amount" => { "nested" => "123.12" }, "something_else" => "value" }
      client = grac.set(:postprocessing => { 'amount$' => ->(value){ BigDecimal.new(value) } })
      expect(client.send(:postprocessing, data)).to eq({
        "amount" => {
          "nested" => "123.12",
        },
        "something_else" => "value"
      })
    end
  end

  context "#build_request" do
    it "sets certain values on Typhoeus" do
      expect(Typhoeus::Request).to receive(:new)
                               .with("http://localhost:80", {
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
                               .with("http://localhost:80", {
                                  :method  => "post",
                                  :params  => {},
                                  :body    => { "abc" => "def" }.to_json,
                                  :connecttimeout => 0.1,
                                  :timeout => 15,
                                  :headers => { "User-Agent" => "Grac v#{Grac::VERSION}" }
                                })
      grac.send(:build_request, "post", { :body => { "abc" => "def" } })
    end

    it "sets params" do
      expect(Typhoeus::Request).to receive(:new)
                               .with("http://localhost:80", {
                                  :method  => "post",
                                  :params  => { "abc" => "def" },
                                  :body    => nil,
                                  :connecttimeout => 0.1,
                                  :timeout => 15,
                                  :headers => { "User-Agent" => "Grac v#{Grac::VERSION}" }
                                })
      grac.send(:build_request, "post", { :params => { "abc" => "def" } })
    end

    it "merges with predefined params" do
      client = grac.set(:params => { "example" => "blub" })
      expect(Typhoeus::Request).to receive(:new)
                               .with("http://localhost:80", {
                                  :method  => "post",
                                  :params  => { "example" => "blub", "abc" => "def" },
                                  :body    => nil,
                                  :connecttimeout => 0.1,
                                  :timeout => 15,
                                  :headers => { "User-Agent" => "Grac v#{Grac::VERSION}" }
                                })
      client.send(:build_request, "post", { :params => { "abc" => "def" } })
    end
  end

  context "#run" do
    let(:request) { double('request', 'options' => { "method" => "get" },
                           'url' => grac.uri) }
    let(:response) { double('response', 'timed_out?' => false, 'code' => 200,
                            'body' => { "value" => "success" }.to_json,
                            'headers' => { 'Content-Type' => 'application/json?encoding=utf-8' }) }

    before do
      expect(request).to receive(:run).and_return(response)
    end

    context "retry" do
      it "retries for get" do
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "retries for head" do
        expect(request).to receive(:run).and_return(response)
        expect(request).to receive(:options).and_return({ :method => "head" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "does not retry for post" do
        expect(request).to receive(:options).and_return({ :method => "post" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "does not retry for put" do
        expect(request).to receive(:options).and_return({ :method => "put" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "does not retry for patch" do
        expect(request).to receive(:options).and_return({ :method => "patch" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "does not retry for delete" do
        expect(request).to receive(:options).and_return({ :method => "delete" })
        expect(response).to receive(:timed_out?).and_return(true, false)
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "raises a ServiceTimeout if the response timed out" do
        expect(request).to receive(:options).and_return({ :method => "put" })
        expect(response).to receive(:timed_out?).twice.and_return(true)
        allow(response).to receive(:return_message).and_return("timeout")
        expect{
          grac.send(:run, request)
        }.to raise_exception(
          Grac::Exception::ServiceTimeout,
          "PUT '#{grac.uri}' timed out: timeout"
        )
      end
    end

    context "response code 200" do
      it "returns a parsed json body" do
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "returns the body as is if the content type is not json" do
        allow(response).to receive(:headers).and_return({ "Content-Type" => "text/plain" })
        expect(grac.send(:run, request)).to eq("{\"value\":\"success\"}")
      end
    end

    context "response code 201" do
      before do
        allow(response).to receive(:code).and_return(201)
      end

      it "returns a parsed json body" do
        expect(grac.send(:run, request)).to eq({ "value" => "success" })
      end

      it "returns the body as is if the content type is not json" do
        allow(response).to receive(:headers).and_return({ "Content-Type" => "text/plain" })
        expect(grac.send(:run, request)).to eq("{\"value\":\"success\"}")
      end
    end

    context "response code 204" do
      before do
        allow(response).to receive(:code).and_return(204)
      end

      it "returns true" do
        expect(grac.send(:run, request)).to eq(true)
      end
    end

    context "response code 0" do
      before do
        allow(response).to receive(:code).and_return(0)
        allow(response).to receive(:return_message).and_return("timeout")
      end

      it "raises a RequestFailed exception" do
        expect(request).to receive(:options).and_return({ :method => "get" })
        expect{
          grac.send(:run, request)
        }.to raise_exception(Grac::Exception::RequestFailed, "GET '#{grac.uri}' failed: timeout")
      end
    end

    context "response code 400" do
      it "raises a Invalid exception" do
        allow(response).to receive(:request).and_return(request)
        allow(response).to receive(:code).and_return(400)
        expect{
          grac.send(:run, request)
        }.to raise_exception(Grac::Exception::BadRequest)
      end
    end

    context "response code 403" do
      it "raises a Forbidden exception" do
        allow(response).to receive(:request).and_return(request)
        allow(response).to receive(:code).and_return(403)
        expect{
          grac.send(:run, request)
        }.to raise_exception(Grac::Exception::Forbidden)
      end
    end

    context "response code 404" do
      it "raises a NotFound exception" do
        allow(response).to receive(:request).and_return(request)
        allow(response).to receive(:code).and_return(404)
        expect{
          grac.send(:run, request)
        }.to raise_exception(Grac::Exception::NotFound)
      end
    end

    context "response code 409" do
      it "raises a Conflict exception" do
        allow(response).to receive(:request).and_return(request)
        allow(response).to receive(:code).and_return(409)
        expect{
          grac.send(:run, request)
        }.to raise_exception(Grac::Exception::Conflict)
      end
    end

    context "other response code e.g. 500" do
      it "raises a ServiceError exception" do
        allow(response).to receive(:request).and_return(request)
        allow(response).to receive(:code).and_return(500)
        expect{
          grac.send(:run, request)
        }.to raise_exception(Grac::Exception::ServiceError)
      end
    end
  end
end
