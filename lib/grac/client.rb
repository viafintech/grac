require 'addressable/template'
require 'addressable/uri'
require 'json'
require 'typhoeus'

require_relative './exception'

module Grac
  class Client
    def initialize(options = {})
      if !options["uri"].nil? && !options["uri"].empty?
        uri = Addressable::URI.parse(options["uri"])
        options["scheme"] ||= uri.scheme
        options["host"]   ||= uri.host
        options["port"]   ||= uri.port
        options["path"]   ||= uri.path
      end

      @options = {
        "scheme"         => options["scheme"]         || 'http',
        "host"           => options["host"]           || 'localhost',
        "port"           => options["port"]           || 80,
        "path"           => options["path"]           || '/',
        "connecttimeout" => options["connecttimeout"] || 0.1,
        "timeout"        => options["timeout"]        || 15,
        "params"         => options["params"]         || {},
        "headers"        => { "User-Agent" => "Grac v#{Grac::VERSION}" }.merge(options["headers"] || {}),
        "postprocessing" => {}
      }

      @options["path"] = Addressable::URI.join("/", @options["path"]).path
    end

    def set(options = {})
      self.class.new(@options.merge(options))
    end

    def set!(options = {})
      @options.merge!(options)
      return self
    end

    def method_missing(m, *args, &block)
      chain = true
      if m =~ /\A(.+)!\z/
        chain = false
        m = $1
      end

      path = join_to_path(m)

      if chain
        return self.class.new(@options.merge({ "path" => path }))
      else
        @options["path"] = path
        return self
      end
    end

    # https://robots.thoughtbot.com/always-define-respond-to-missing-when-overriding
    def respond_to_missing?(method_name, include_private = false)
      private_methods.include?(method_name.to_sym) ? super : true
    end

    # Defines var, var!, type, type!, expand, expand!, partial_expand and partial_expand!
    %w{var type expand partial_expand}.each do |method|
      define_method method do |param|
        return self.class.new(@options.merge({ "path" => send("#{method}_logic", param) }))
      end

      define_method "#{method}!" do |param|
        @options["path"] = send("#{method}_logic", param)
        return self
      end
    end

    def uri
      "#{@options["scheme"]}://#{@options["host"]}:#{@options["port"]}#{@options["path"]}"
    end

    %w{post put patch}.each do |method|
      define_method method do |body = {}, params = {}|
        request = build_request(method, { "body" => body, "params" => params })
        handle_response(request)
      end
    end

    %w{get delete}.each do |method|
      define_method method do |params = {}|
        request = build_request(method, { "params" => params })
        handle_response(request)
      end
    end

    private
      def var_logic(var)
        return join_to_path(var)
      end

      def type_logic(type)
        return join_to_path(type, ".")
      end

      def expand_logic(options)
        return Addressable::Template.new(@options["path"]).expand(options).path
      end

      def partial_expand_logic(options)
        return Addressable::Template.new(@options["path"]).partial_expand(options).pattern
      end

      def join_to_path(value, sep = "/")
        separator = @options["path"].reverse[0,1] == sep ? '' : sep
        return "#{@options["path"]}#{separator}#{value}"
      end

      def build_request(method, options = {})
        body = options["body"].nil? || options["body"].empty? ? nil : options["body"].to_json

        request_hash = { :method => method }
        request_hash[:params]         = @options["params"].merge(options["params"] || {})
        request_hash[:body]           = body
        request_hash[:connecttimeout] = @options["connecttimeout"]
        request_hash[:timeout]        = @options["timeout"]
        request_hash[:headers]        = @options["headers"]

        return ::Typhoeus::Request.new(uri, request_hash)
      end

      def parse_json(body)
        JSON.parse(body)
      end

      def postprocessing(data, processing = nil)
        return data if @options["postprocessing"].nil? || @options["postprocessing"].empty?

        if data.kind_of?(Hash)
          data.each do |key, value|
            processing = nil
            @options["postprocessing"].each do |regex, action|
              if /#{regex}/ =~ key
                processing = action
              end
            end

            if value.kind_of?(Hash) || value.kind_of?(Array)
              data[key] = postprocessing(value, processing)
            else
              data[key] = postprocessing(value, processing)
            end
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

      def handle_response(request)
        response = request.run

        # Retry GET and HEAD requests - modifying requests might not be idempotent
        method = request.options["method"].to_s.downcase
        response = request.run if response.timed_out? && ['get', 'head'].include?(method)

        # A request can time out while receiving data. In this case response.code might indicate
        # success although data hasn't been fully transferred. Thus rely on Typhoeus for
        # detecting a timeout.
        if response.timed_out?
          raise Exception::ServiceTimeout.new(
            "Service timed out: #{response.return_message}")
        end

        case response.code
          when 200, 201
            begin
              result = parse_json(response.body)
              return postprocessing(result)
            rescue JSON::ParserError
              return response.body
            end
          when 204
            return true
          when 0
            raise Exception::RequestFailed.new(
              "Service request failed: #{response.return_message}")
          when 400
            raise Exception::Invalid.new(response)
          when 403
            raise Exception::Forbidden.new(response)
          when 404
            raise Exception::NotFound.new(response)
          when 409
            raise Exception::Conflict.new(response)
          else
            raise Exception::ServiceError.new(response)
        end
      end
  end
end
