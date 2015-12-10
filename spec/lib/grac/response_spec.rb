require 'spec_helper'

describe Grac::Response do
  let(:response)          { described_class.new(typhoeus_response) }
  let(:typhoeus_response) { double("Typhoeus::Response") }
  let(:content_type)      { 'application/json' }
  let(:body)              { '{"json": "response"}' }

  before do
    allow(typhoeus_response).to receive(:headers)
                            .and_return({ 'Content-Type' => content_type })
    allow(typhoeus_response).to receive(:body).and_return(body)
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
