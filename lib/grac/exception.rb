require 'json'

module Grac
  module Exception
    class ClientException < StandardError
      attr_reader :url, :method, :body

      def initialize(method, url, body)
        @method    = (method || "").upcase
        @url       = url
        @body      = body
      end

      def inspect
        "#{self.class.name}: #{message}"
      end

      def message
        "#{@method} '#{@url}' failed with content: #{@body}"
      end

      alias_method :to_s, :message
    end

    class BadRequest   < ClientException; end
    class Forbidden    < ClientException; end
    class NotFound     < ClientException; end
    class Conflict     < ClientException; end
    class ServiceError < ClientException; end

    class RequestFailed  < StandardError
      attr_reader :method, :url

      def initialize(method, url, message)
        @method  = (method || "").upcase
        @url     = url
        @message = message
      end

      def message
        "#{@method} '#{@url}' failed: #{@message}"
      end

      def inspect
        "#{self.class.name}: #{message}"
      end

      alias_method :to_s, :message
    end

    class ServiceTimeout < RequestFailed
      def message
         "#{@method} '#{@url}' timed out: #{@message}"
      end
    end

    class InvalidContent < StandardError
      def initialize(body, type)
        @body = body
        @type = type
      end

      def message
        "Failed to process '#{@body}' as type '#{@type}'"
      end

      def inspect
        "#{self.class.name}: #{message}"
      end

      alias_method :to_s, :message
    end
  end
end
