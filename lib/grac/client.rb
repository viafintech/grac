require 'json'
require 'typhoeus'
require 'uri'

require_relative './exception'
require_relative './response'

module Grac
  class Client
    attr_reader :uri

    def initialize(uri, options = {})
      URI.parse(uri)

      @uri = uri
      @options = {
        :connecttimeout => options[:connecttimeout] || 0.1,
        :timeout        => options[:timeout]        || 15,
        :params         => options[:params]         || {},
        :headers        => { "User-Agent" => "Grac v#{Grac::VERSION}" }.merge(options[:headers] || {}),
        :postprocessing => options[:postprocessing] || {},
        :middleware     => options[:middleware]     || []
      }
      @options.freeze
      [:params, :headers, :postprocessing, :middleware].each do |k|
        @options[k].freeze
      end
      @uri.freeze
    end

    def set(options = {})
      options = options.merge({
        headers:    @options[:headers].merge(options[:headers]    || {}),
        middleware: @options[:middleware] + (options[:middleware] || [])
      })

      self.class.new(@uri, @options.merge(options))
    end

    def path(path, variables = {})
      variables.each do |key, value|
        path = path.gsub("{#{key}}", value)
      end
      self.class.new("#{@uri}#{path}", @options)
    end

    %w{post put patch}.each do |method|
      define_method method do |body = {}, params = {}|
        response = build_and_run(method, { :body => body, :params => params })
        check_response(method, response)
      end
    end

    %w{get delete}.each do |method|
      define_method method do |params = {}|
        response = build_and_run(method, { :params => params })
        check_response(method, response)
      end
    end

    def call(opts, request_uri, method, params, body)
      request_hash = {
        :method         => method,
        :params         => params,
        :body           => body,
        :connecttimeout => opts[:connecttimeout],
        :timeout        => opts[:timeout],
        :headers        => opts[:headers]
      }

      request  = ::Typhoeus::Request.new(request_uri, request_hash)
      response = request.run

      # Retry GET and HEAD requests - modifying requests might not be idempotent
      response = request.run if response.timed_out? && ['get', 'head'].include?(method)

      # A request can time out while receiving data. In this case response.code might indicate
      # success although data hasn't been fully transferred. Thus rely on Typhoeus for
      # detecting a timeout.
      if response.timed_out?
        raise Exception::ServiceTimeout.new(method, request.url, response.return_message)
      end

      return Response.new(response)
    end

    private

      def build_and_run(method, options = {})
        body   = options[:body].nil? || options[:body].empty? ? nil : options[:body].to_json
        params = @options[:params].merge(options[:params] || {})
        return wrapped_request.call(@options, uri, method, params, body)
      end

      def wrapped_request
        caller = self

        @options[:middleware].reverse.each do |mw|
          if mw.kind_of?(Array)
            middleware_class = mw[0]
            params           = mw[1..-1]

            caller = middleware_class.new(caller, *params)
          else
            caller = mw.new(caller)
          end
        end

        return caller
      end

      def check_response(method, response)
        case response.code
          when 200..203, 206..299
            # unknown status codes must be treated as the x00 of their class, so 200
            if response.json_content?
              return postprocessing(response.parsed_json)
            end

            return response.body
          when 204, 205
            return true
          when 0
            raise Exception::RequestFailed.new(method, response.effective_url, response.return_message)
          when 400
            raise Exception::BadRequest.new(method, response.effective_url, response.parsed_or_raw_body)
          when 403
            raise Exception::Forbidden.new(method, response.effective_url, response.parsed_or_raw_body)
          when 404
            raise Exception::NotFound.new(method, response.effective_url, response.parsed_or_raw_body)
          when 409
            raise Exception::Conflict.new(method, response.effective_url, response.parsed_or_raw_body)
          else
            raise Exception::ServiceError.new(method, response.effective_url, response.parsed_or_raw_body)
        end
      end

      def postprocessing(data, processing = nil)
        return data if @options[:postprocessing].nil? || @options[:postprocessing].empty?

        if data.kind_of?(Hash)
          data.each do |key, value|
            processing = nil
            @options[:postprocessing].each do |regex, action|
              if /#{regex}/ =~ key
                processing = action
              end
            end

            data[key] = postprocessing(value, processing)
          end
        elsif data.kind_of?(Array)
          data.each_with_index do |value, index|
            data[index] = postprocessing(value, processing)
          end
        else
          data = processing.nil? ? data : processing.call(data)
        end

        return data
      end
  end
end
