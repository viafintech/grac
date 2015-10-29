require 'json'

require_relative './exception'

module Grac
  module ResponseProcessing
    def process_response(body, content_type)
      if !content_type.nil? && content_type.match('application/json')
        return parse_json(body)
      else
        return body
      end
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError
      raise Grac::Exception::InvalidContent.new(body, 'json')
    end
  end
end
