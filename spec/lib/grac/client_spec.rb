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
        :postprocessing => {},
        :middleware    => []
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

    it "merges headers instead of overwriting them" do
      a_client = grac.set({ :headers => { "User-Agent" => "123445" } })
      b_client = a_client.set({ :headers => { "Request-Id" => "123445" } })
      check_options(b_client, :headers, {
        "User-Agent" => "123445", "Request-Id" => "123445"
      })
    end

    it "merges middleware instead of overwriting them" do
      a_client = grac.set({ :middleware => ["abc"] })
      b_client = a_client.set({ :middleware => ["cde"] })
      check_options(b_client, :middleware, ["abc", "cde"])
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
          expect(grac).to receive(:build_and_run)
                      .with(method, { :body => {}, :params => {} })
                      .and_return(double = Object.new)
          expect(grac).to receive(:check_response).with(method, double).and_return(true)
          expect(grac.send(method)).to eq(true)
        end
      end
    end

    %w{get delete}.each do |method|
      context "##{method}" do
        it "calls build request with params" do
          expect(grac).to receive(:build_and_run)
                      .with(method, { :params => {} })
                      .and_return(double = Object.new)
          expect(grac).to receive(:check_response).with(method, double).and_return(true)
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

  context "#call" do
    let(:opts)        { { connecttimeout: 1, timeout: 3, headers: { "User-Agent" => "test" } } }
    let(:method)      { "get" }
    let(:params)      { { "param1" => "value" } }
    let(:body)        { "body" }

    let(:request_uri) { "http://example.com" }
    let(:request_hash) {
      {
        method:         method,
        params:         params,
        body:           body,
        connecttimeout: opts[:connecttimeout],
        timeout:        opts[:timeout],
        headers:        opts[:headers]
      }
    }

    before do
      expect(::Typhoeus::Request).to receive(:new)
        .with(request_uri, request_hash)
        .and_return(@request = double('request', url: request_uri))
    end

    context "the request timed out" do
      it "raises an exception if the retry was not successful either" do
        expect(@request).to receive(:run).twice.and_return(
          response = double('response', body: body, return_message: "msg")
        )
        expect(response).to receive(:timed_out?).twice.and_return(true)

        expect{
          grac.call(opts, request_uri, method, params, body)
        }.to raise_error(::Grac::Exception::ServiceTimeout, "GET 'http://example.com' timed out: msg")
      end

      context "post" do
        let(:method) { "post" }

        it "raises an exception if the request timed out" do
          expect(@request).to receive(:run).and_return(
            response = double('response', body: body, return_message: "msg")
          )
          expect(response).to receive(:timed_out?).twice.and_return(true)

          expect{
            grac.call(opts, request_uri, method, params, body)
          }.to raise_error(::Grac::Exception::ServiceTimeout, "POST 'http://example.com' timed out: msg")
        end
      end
    end

    context "success" do
      after do
        expect(@r.class).to eq(::Grac::Response)
        expect(@r.body).to eq(body)
      end

      it "builds the request with the given parameters and executes it" do
        expect(@request).to receive(:run).and_return(response = double('response', body: body))
        expect(response).to receive(:timed_out?).twice.and_return(false)

        @r = grac.call(opts, request_uri, method, params, body)
      end

      it "retries if the request timed_out in the beginning" do
        expect(@request).to receive(:run).twice.and_return(response = double('response', body: body))
        expect(response).to receive(:timed_out?).twice.and_return(true, false)

        @r = grac.call(opts, request_uri, method, params, body)
      end

      context "post" do
        let(:method) { "post" }

        it "does not retry if the http method is not get/head" do
          expect(@request).to receive(:run).and_return(response = double('response', body: body))
          expect(response).to receive(:timed_out?).twice.and_return(true, false)

          @r = grac.call(opts, request_uri, method, params, body)
        end
      end
    end
  end

  context "wrapped_request" do
    after do
      caller = @client.send(:wrapped_request)

      expect(
        ::Typhoeus::Request
      ).to receive(:new).with(
        "http://example.com",
        {
          method:         "GET",
          params:         {},
          body:           "",
          connecttimeout: nil,
          timeout:        nil,
          headers:        nil
        }
      ).and_return(request = double('request'))
      expect(request).to receive(:run).and_return(response = double('response'))
      allow(response).to receive(:timed_out?).and_return(false)
      response_object = caller.call({}, "http://example.com", "GET", {}, "")
      expect(response_object.class).to eq(::Grac::Response)
    end

    it "wraps all middleware around execute_request" do
      @client = grac.set(:middleware => [TestMiddleware])
      expect(TestMiddleware).to receive(:new).with(@client).and_call_original
    end

    it "calls the middleware with configuration parameters" do
      @client = grac.set(:middleware => [[TestMiddleware, "abc", { key: "value"}]])
      expect(TestMiddleware).to receive(:new).with(@client, "abc", { key: "value" }).and_call_original
    end
  end

  context "#build_and_run" do
    it "builds the parameters and passes them to the wrapped_request" do
      expect(grac).to receive(:wrapped_request).and_return(middleware_stack = double('mw'))
      expect(middleware_stack).to receive(:call).with(
        grac.instance_variable_get(:@options), grac.uri, "get", {}, nil
      ).and_return(1)
      expect(grac.send(:build_and_run, "get", {})).to eq(1)
    end

    it "calls the wrapped_request with a body" do
      expect(grac).to receive(:wrapped_request).and_return(middleware_stack = double('mw'))
      expect(middleware_stack).to receive(:call).with(
        grac.instance_variable_get(:@options), grac.uri, "get", {}, { data: "asd" }.to_json
      ).and_return(1)
      expect(grac.send(:build_and_run, "get", { :body => { data: "asd" } })).to eq(1)
    end

    it "calls the wrapped_request with a params" do
      expect(grac).to receive(:wrapped_request).and_return(middleware_stack = double('mw'))
      expect(middleware_stack).to receive(:call).with(
        grac.instance_variable_get(:@options), grac.uri, "get", { data: "asd" }, nil
      ).and_return(1)
      expect(grac.send(:build_and_run, "get", { :params => { data: "asd" } })).to eq(1)
    end

    it "calls the wrapped_request with predefined parameters" do
      client = grac.set(params: { "a" => "b" })

      expect(client).to receive(:wrapped_request).and_return(middleware_stack = double('mw'))
      expect(middleware_stack).to receive(:call).with(
        client.instance_variable_get(:@options), client.uri, "get", { "a" => "b", "c" => "b" }, nil
      ).and_return(1)
      expect(client.send(:build_and_run, "get", { :params => { "c" => "b" } })).to eq(1)
    end
  end

  context "#check_response" do
    let(:method)            { "GET" }
    let(:response_code)     { 200 }
    let(:return_message)    { nil }
    let(:response_headers)  { { 'Content-Type' => 'application/json?encoding=utf-8' } }
    let(:response_body)     { { "value" => "success" }.to_json }
    let(:typhoeus_response) { double('response', 'effective_url' => grac.uri,
                                     'code' => response_code, 'return_message' => return_message,
                                     'body' => response_body,
                                     'headers' => response_headers) }
    let(:grac_response) {
      Grac::Response.new(typhoeus_response)
    }

    context "204" do
      let(:response_code) { 204 }

      it "returns true" do
        expect(grac.send(:check_response, method, grac_response)).to eq(true)
      end
    end

    context "205" do
      let(:response_code) { 205 }

      it "returns true" do
        expect(grac.send(:check_response, method, grac_response)).to eq(true)
      end
    end

    context "2XX" do
      it "returns the parsed json body" do
        expect(grac.send(:check_response, method, grac_response)).to eq({ "value" => "success" })
      end

      it "returns the parsed json body with postprocessing" do
        client = grac.set(:postprocessing => { "value" => ->(val){ return val.upcase } })
        expect(client.send(:check_response, method, grac_response)).to eq({ "value" => "SUCCESS" })
      end

      context "raw body" do
        let(:response_headers) { {} }

        it "returns the raw body" do
          expect(
            grac.send(:check_response, method, grac_response)
          ).to eq({ "value" => "success" }.to_json)
        end
      end
    end

    context "0" do
      let(:response_code) { 0 }
      let(:return_message) { "timeout" }

      it "raises a RequestFailed exception" do
        expect{
          grac.send(:check_response, method, grac_response)
        }.to raise_exception(Grac::Exception::RequestFailed, "GET '#{grac.uri}' failed: timeout")
      end
    end

    context "400" do
      let(:response_code) { 400 }

      context "json" do
        it "raises a BadRequest exception" do
          expect{
            grac.send(:check_response, method, grac_response)
          }.to raise_exception(
            Grac::Exception::BadRequest,
            "GET '#{grac.uri}' failed with content: {\"value\"=>\"success\"}"
          )
        end
      end

      context "plain text" do
        let(:response_headers) { { "Content-Type" => "text/plain" } }

        it "raises a BadRequest exception" do
          expect{
            grac.send(:check_response, method, grac_response)
          }.to raise_exception(
            Grac::Exception::BadRequest,
            "GET '#{grac.uri}' failed with content: {\"value\":\"success\"}"
          )
        end
      end
    end

    context "403" do
      let(:response_code) { 403 }

      it "raises a Forbidden exception" do
        expect{
          grac.send(:check_response, method, grac_response)
        }.to raise_exception(
          Grac::Exception::Forbidden,
          "GET '#{grac.uri}' failed with content: {\"value\"=>\"success\"}"
        )
      end
    end

    context "404" do
      let(:response_code) { 404 }

      it "raises a NotFound exception" do
        expect{
          grac.send(:check_response, method, grac_response)
        }.to raise_exception(
          Grac::Exception::NotFound,
          "GET '#{grac.uri}' failed with content: {\"value\"=>\"success\"}"
        )
      end
    end

    context "409" do
      let(:response_code) { 409 }

      it "raises a Conflict exception" do
        expect{
          grac.send(:check_response, method, grac_response)
        }.to raise_exception(
          Grac::Exception::Conflict,
          "GET '#{grac.uri}' failed with content: {\"value\"=>\"success\"}"
        )
      end
    end

    context "500/others" do
      let(:response_code) { 500 }

      it "raises a ServiceError exception" do
        expect{
          grac.send(:check_response, method, grac_response)
        }.to raise_exception(
          Grac::Exception::ServiceError,
          "GET '#{grac.uri}' failed with content: {\"value\"=>\"success\"}"
        )
      end
    end
  end
end
