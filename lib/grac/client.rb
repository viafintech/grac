require 'cgi'
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
        connecttimeout: options[:connecttimeout] || 0.1,
        timeout:        options[:timeout]        || 15,
        params:         options[:params]         || {},
        headers:        {
          'User-Agent'   => "Grac v#{Grac::VERSION}",
          'Content-Type' => 'application/json;charset=utf-8'
        }.merge(options[:headers] || {}),
        postprocessing: {},
        middleware:     options[:middleware] || [],
        retry_get_head: options.fetch(:retry_get_head, true),
      }

      if options[:postprocessing]
        options[:postprocessing]
          .each_with_object(postprocessing = {}) do |(pattern, transformation), obj|
          if pattern.is_a?(Regexp)
            obj[pattern] = transformation
          else
            obj[Regexp.new(pattern)] = transformation
          end
        end

        @options[:postprocessing] = postprocessing
      end

      @options.freeze

      [:params, :headers, :postprocessing, :middleware].each do |k|
        @options[k].freeze
      end

      @uri.freeze
    end

    def set(options = {})
      options = options.merge(
                  {
                    headers:    @options[:headers].merge(options[:headers]    || {}),
                    middleware: @options[:middleware] + (options[:middleware] || []),
                  },
                )

      self.class.new(@uri, @options.merge(options))
    end

    def path(path, variables = {})
      variables.each do |key, value|
        path = path.gsub("{#{key}}", escape_url_param(value))
      end
      self.class.new("#{@uri}#{path}", @options)
    end

    ['post', 'put', 'patch'].each do |method|
      define_method method do |body = {}, params = {}|
        response = build_and_run(method, { body: body, params: params })
        check_response(method, response)
      end
    end

    ['get', 'delete'].each do |method|
      define_method method do |params = {}|
        response = build_and_run(method, { params: params })
        check_response(method, response)
      end
    end

    def call(opts, request_uri, method, params, body)
      request_hash = {
        method:         method,
        params:         params,  # Query params are escaped by Typhoeus
        body:           body,
        connecttimeout: opts[:connecttimeout],
        timeout:        opts[:timeout],
        headers:        opts[:headers],
      }

      request  = ::Typhoeus::Request.new(request_uri, request_hash)
      response = request.run

      # Retry GET and HEAD requests - modifying requests might not be idempotent
      # Only retry those requests if the feature is enabled
      if response.timed_out? && ['get', 'head'].include?(method) && @options[:retry_get_head]
        response = request.run
      end

      # A request can time out while receiving data. In this case response.code might indicate
      # success although data hasn't been fully transferred. Thus rely on Typhoeus for
      # detecting a timeout.
      if response.timed_out?
        raise Exception::ServiceTimeout.new(method, request.url, response.return_message)
      end

      # List of possible codes
      # https://github.com/typhoeus/ethon/blob/ab052b6a317309b6ae8be7b538738b138b11437a/lib/ethon/curls/codes.rb#L10
      case response.return_code
      # A request may have received a response but may have aborted while receiving the data.
      # Typhoeus does not necessarily consider this a timeout but might try to parse a response.
      # If the response content length does not match the content length header,
      # the return code will be :partial_file.
      # In that case we do not want to pass it on as it would result in JSON Parser errors
      # due to invalid JSON from the incomplete response.
      when :partial_file
        raise Exception::PartialResponse.new(method, request.url, response.return_message)
      end

      return Response.new(response)
    end

    private

      def build_and_run(method, options = {})
        body   = prepare_body_by_content_type(options[:body])
        params = @options[:params].merge(options[:params] || {})
        return middleware_chain.call(@options, uri, method, params, body)
      end

      def headers
        @options[:headers] || {}
      end

      def prepare_body_by_content_type(body)
        return nil if body.nil? || body.empty?

        case headers['Content-Type']
        when /\Aapplication\/json/
          return body.to_json
        when /\Aapplication\/x-www-form-urlencoded/
          # Typhoeus will take care of the encoding when receiving a hash
          return body
        else
          # Do not encode other unknown Content-Types either.
          # The default is JSON through the Content-Type header which is set by default.
          return body
        end
      end

      def middleware_chain
        callee = self

        @options[:middleware].reverse.each do |mw|
          if mw.kind_of?(Array)
            middleware_class = mw[0]
            params           = mw[1..-1]

            callee = middleware_class.new(callee, *params)
          else
            callee = mw.new(callee)
          end
        end

        return callee
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
          else
            begin
              # The Response class doesn't have enough information to create a proper exception, so
              # catch its exception and raise a proper one.
              parsed_body = response.parsed_json
            rescue Exception::InvalidContent
              raise Exception::ErrorWithInvalidContent.new(
                method,
                response.effective_url,
                response.code,
                response.body,
                'json'
              )
            end
            case response.code
            when 400
              raise Exception::BadRequest.new(method, response.effective_url, parsed_body)
            when 403
              raise Exception::Forbidden.new(method, response.effective_url, parsed_body)
            when 404
              raise Exception::NotFound.new(method, response.effective_url, parsed_body)
            when 409
              raise Exception::Conflict.new(method, response.effective_url, parsed_body)
            else
              raise Exception::ServiceError.new(method, response.effective_url, parsed_body)
            end
        end
      end

      def postprocessing(data, processing = nil)
        return data if @options[:postprocessing].nil? || @options[:postprocessing].empty?

        if data.kind_of?(Hash)
          data.each do |key, value|
            processing = nil
            regexp = @options[:postprocessing].keys.detect { |pattern| pattern.match?(key) }

            if !regexp.nil?
              processing = @options[:postprocessing][regexp]
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

      def escape_url_param(value)
        # We don't want spaces to be encoded as plus sign - a plus sign can be ambiguous in a URL and
        # either represent a plus sign or a space.
        # CGI::escape replaces all plus signs with their percent-encoding representation, so all
        # remaining plus signs are spaces. Replacing these with a space's percent encoding makes the
        # encoding unambiguous.
        CGI::escape(value).gsub('+', '%20')
      end

  end
end
