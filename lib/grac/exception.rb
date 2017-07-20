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

    class PartialResponse < RequestFailed
      def message
        "#{@method} '#{@url}' returned an incomplete response body: #{@message}"
      end
    end

    class InvalidContent < StandardError
      def initialize(body, type)
        @body = body
        @type = type
      end

      def message
        "Failed to parse body as '#{@type}': '#{@body}'"
      end

      def inspect
        "#{self.class.name}: #{message}"
      end

      alias_method :to_s, :message
    end

    class ErrorWithInvalidContent < StandardError
      def initialize(method, url, status, raw_body, expected_type)
        @method = (method || "").upcase
        @url = url
        @status = status
        @raw_body = raw_body
        @expected_type = expected_type
      end

      def message
        "#{@method} '#{@url}': Got HTTP #{@status}, failed to parse as '#{@expected_type}'. " \
        "Raw Body: '#{@raw_body}'"
      end

      def inspect
        "#{self.class.name}: #{message}"
      end

      alias_method :to_s, :message
    end
  end
end
