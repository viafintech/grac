require 'spec_helper'

describe Grac::Response do
  let(:response)          { described_class.new(typhoeus_response) }
  let(:typhoeus_response) { double("Typhoeus::Response") }
  let(:content_type)      { 'application/json' }
  let(:body)              { '{"json": "response"}' }
  let(:code)              { 200 }
  let(:effective_url)     { "http://example.com" }
  let(:return_message)    { "Timed out" }

  before do
    allow(typhoeus_response).to receive(:headers)
                            .and_return({ 'Content-Type' => content_type })
    allow(typhoeus_response).to receive(:body).and_return(body)
    allow(typhoeus_response).to receive(:code).and_return(code)
    allow(typhoeus_response).to receive(:effective_url).and_return(effective_url)
    allow(typhoeus_response).to receive(:return_message).and_return(return_message)
  end

  describe '#code' do
    it "forwards the response code" do
      expect(response.code).to eq(code)
    end
  end

  describe '#effective_url' do
    it "forwards the effective_url" do
      expect(response.effective_url).to eq(effective_url)
    end
  end

  describe '#headers' do
    it "forwards the headers" do
      expect(response.headers).to eq({ 'Content-Type' => content_type })
    end
  end

  describe '#return_message' do
    it "forwards the return_message" do
      expect(response.return_message).to eq(return_message)
    end
  end

  describe '#json_content?' do
    context 'for a JSON response' do
      it 'is true' do
        expect(response.json_content?).to be_truthy
      end
    end

    context 'for a plain text response' do
      let(:content_type) { 'application/plain' }

      it 'is false' do
        expect(response.json_content?).to be_falsey
      end
    end
  end

  describe '#parsed_json' do
    it 'returns parsed json' do
      expect(response.parsed_json).to eq({'json' => 'response'})
    end

    context 'for invalid json' do
      let(:body) { 'INVALID JSON' }

      it 'raises an InvalidContent exception' do
        expect {
          response.parsed_json
        }.to raise_error(Grac::Exception::InvalidContent)
      end
    end
  end

  describe '#parsed_or_raw_body' do
    it 'returns parsed json' do
      expect(response.parsed_or_raw_body).to eq({'json' => 'response'})
    end

    context 'for invalid json' do
      let(:body) { 'INVALID JSON' }

      it 'returns the raw body' do
        expect(response.parsed_or_raw_body).to eq 'INVALID JSON'
      end
    end
  end
end
