require 'json'

module Grac
  module Exception
    class ClientException < StandardError
      attr_reader :http_code, :service_response, :object, :error, :message, :errors, :url

      def initialize(response)
        @http_code = response.code
        @service_response = parse_json(response.body)
        @url     = response.request.url
        @object  = @service_response["object"].to_sym if @service_response["object"]
        @error   = @service_response["error"].to_sym  if @service_response["error"]
        @message = @service_response["message"]
        @errors  = @service_response["errors"] || {}
      end

      def inspect
        "#{self.class.name}: #{@service_response}"
      end

      def to_s
        @message.nil? || @message.empty? ? self.class.name : @message
      end

      private

        def parse_json(body)
          JSON.parse(body)
        end

    end

    class Invalid        < ClientException; end
    class Forbidden      < ClientException; end
    class NotFound       < ClientException; end
    class Conflict       < ClientException; end
    class ServiceError   < ClientException; end
    class RequestFailed  < StandardError; end
    class ServiceTimeout < RequestFailed; end
  end
end
