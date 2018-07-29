RSpec.shared_examples 'download utils' do
  let(:dummy_http) { double }
  let(:dummy_req) { double }
  let(:source) { 'https://res.image.cloudinary.loc' }
  let(:body) { 'some string thingy' }

  before do
    stub_const('Net::HTTP::Get', dummy_req)
    allow(Net::HTTP).to receive(:new) { dummy_http }

    allow(dummy_http).to receive(:start).and_yield(dummy_http)
    allow(dummy_http).to receive(:use_ssl=)
    allow(dummy_http).to receive(:verify_mode=)
    allow(dummy_http).to receive(:force_encoding)
    allow(dummy_http).to receive(:body).and_return(body)
    allow(dummy_http).to receive(:request).with(dummy_req) { dummy_http }

    allow(dummy_req).to receive(:new) { dummy_req }
  end


  describe 'download_range' do
    let(:range) { 4..16 }

    it 'sets the request range to the given range' do
      expect(dummy_req).to receive(:range=).with(range)

      subject.download_range(source, range)
    end
  end


  describe 'stream_download' do
    let(:chunks) { [] }
    let(:block) { ->(chunk) { chunks << chunk } }
    before do
      allow(dummy_http).to receive(:request_head).and_return(dummy_http)
      allow(dummy_http).to receive(:content_length).and_return(7)
    end

    context 'chunk size is greater than content_length' do
      it 'yields all the content' do
        expect(dummy_req).to receive(:range=).with(0..100)

        subject.stream_download(source, 100, &block)

        expect(chunks).to eq [body]
      end
    end

    context 'chunk_size is less than content_length' do
      it 'yields the content in chunks of the given chunk size' do
        expect(dummy_req).to receive(:range=).once.ordered.with(0..2)
        expect(dummy_req).to receive(:range=).once.ordered.with(3..5)
        expect(dummy_req).to receive(:range=).once.ordered.with(6..8)

        subject.stream_download(source, 2, &block)
        expect(chunks.size).to eq 3
      end
    end
  end
end
