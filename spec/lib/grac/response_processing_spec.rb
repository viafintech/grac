require 'spec_helper'

describe Grac::ResponseProcessing do
  let(:obj) { o = Object.new; o.extend(Grac::ResponseProcessing) }

  context "process_response" do
    it "processes as json if content_type matches 'application/json'" do
      expect(
        obj.process_response('{ "a": "c" }', 'application/json')
      ).to eq({ "a" => "c" })
    end

    it "does not do special processing if the content type is not known" do
      expect(
        obj.process_response('{ "a": "c" }', 'text/plain')
      ).to eq('{ "a": "c" }')
    end
  end

  context "parse_json" do
    it "parses valid json" do
      expect(obj.parse_json('{ "a": "c" }')).to eq({ "a" => "c" })
      expect(obj.parse_json('[1, 2]')).to eq([1, 2])
    end

    it "raises an exception if the json is not valid" do
      expect {
        obj.parse_json('cookie')
      }.to raise_error Grac::Exception::InvalidContent, "Failed to process 'cookie' as type 'json'"
    end
  end
end
