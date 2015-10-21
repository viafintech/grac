require 'json'
require 'typhoeus'
require 'uri'

require_relative './exception'

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
        :postprocessing => options[:postprocessing] || {}
      }
    end

    def set(options = {})
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
        request = build_request(method, { :body => body, :params => params })
        run(request)
      end
    end

    %w{get delete}.each do |method|
      define_method method do |params = {}|
        request = build_request(method, { :params => params })
        run(request)
      end
    end

    private
      def build_request(method, options = {})
        body = options[:body].nil? || options[:body].empty? ? nil : options[:body].to_json

        request_hash = { :method => method }
        request_hash[:params]         = @options[:params].merge(options[:params] || {})
        request_hash[:body]           = body
        request_hash[:connecttimeout] = @options[:connecttimeout]
        request_hash[:timeout]        = @options[:timeout]
        request_hash[:headers]        = @options[:headers]

        return ::Typhoeus::Request.new(uri, request_hash)
      end

      def parse_json(body)
        JSON.parse(body)
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

      def run(request)
        response = request.run

        # Retry GET and HEAD requests - modifying requests might not be idempotent
        method = request.options[:method].to_s.downcase
        response = request.run if response.timed_out? && ['get', 'head'].include?(method)

        # A request can time out while receiving data. In this case response.code might indicate
        # success although data hasn't been fully transferred. Thus rely on Typhoeus for
        # detecting a timeout.
        if response.timed_out?
          raise Exception::ServiceTimeout.new(method, request.url, response.return_message)
        end

        case response.code
          when 200, 201
            content_type = response.headers["Content-Type"]
            if content_type.match("application/json")
              result = parse_json(response.body)
              return postprocessing(result)
            else
              return response.body
            end
          when 204
            return true
          when 0
            raise Exception::RequestFailed.new(method, request.url, response.return_message)
          when 400
            raise Exception::BadRequest.new(method, request.url, response.body)
          when 403
            raise Exception::Forbidden.new(method, request.url, response.body)
          when 404
            raise Exception::NotFound.new(method, request.url, response.body)
          when 409
            raise Exception::Conflict.new(method, request.url, response.body)
          else
            raise Exception::ServiceError.new(method, request.url, response.body)
        end
      end
  end
end
