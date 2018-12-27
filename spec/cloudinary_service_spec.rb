require 'download_utils'

RSpec.describe ActiveStorage::Service::CloudinaryService do
  let(:subject) { ActiveStorage::Service::CloudinaryService.new(config) }
  let(:key) { 'some-resource-key' }
  let(:file) { double }
  let(:download_util) { double }
  let(:checksum) { 'zyxddfs' }

  let(:config) do
    {
      cloud_name: 'name',
      api_key:    'abcde',
      api_secret: '12345'
    }
  end

  before do
    stub_const('Cloudinary', DummyCloudinary)
    allow(file).to receive(:extension_with_delimiter).and_return('.png')
  end

  include_examples 'download utils'

  describe '#new' do
    it 'setups cloudinary sdk with the given config' do
      ActiveStorage::Service::CloudinaryService.new(config)
      config.each do |key, value|
        expect(Cloudinary.send(key)).to eq value
      end
    end

    it 'allows extra params' do
      xtra = { upload_preset: 'some-preset', cname: 'some-cname' }
      ActiveStorage::Service::CloudinaryService.new(config.merge(xtra))
      xtra.each do |key, value|
        expect(Cloudinary.send(key)).to eq value
      end
    end
  end

  describe '#upload' do
    it 'calls the upload method on the cloudinary sdk with the given args' do
      expect(Cloudinary::Uploader)
        .to receive(:upload).with(file, public_id: key, resource_type: 'auto')

      subject.upload(key, file)
    end

    it 'instruments the operation' do
      options = { key: key, checksum: checksum }
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:upload, options)

      subject.upload(key, file, checksum: checksum)
    end
  end

  describe '#download' do
    context 'when block is given' do
      it 'calls the stream_download method' do
        block = -> { 'some block' }

        expect(subject).to receive(:stream_download)
          .with('https://some-resource-key') { |&blk| expect(blk).to be(block) }
        expect(Cloudinary::Downloader).not_to receive(:download)

        subject.download(key, &block)
      end
    end

    context 'when no block is given' do
      it 'calls the cloudinary downloader download method' do
        source = DummyCloudinary::Utils.cloudinary_url(key, sign_url: true)
        expect(Cloudinary::Downloader).to receive(:download).with(source)
        expect(subject).not_to receive(:stream_download)

        subject.download(key)
      end
    end

    it 'instruments the operation' do
      options = { key: key }
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:download, options)

      subject.download(key)
    end
  end

  describe '#download_chunk' do
    let(:range) { 1..10 }

    it 'calls the download range method' do
      expect(subject).to receive(:download_range)
        .with('https://some-resource-key', range)
      subject.download_chunk(key, range)
    end

    it 'instruments the operation' do
      options = { key: key, range: range }
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:download_chunk, options)

      subject.download_chunk(key, range)
    end
  end

  describe '#delete' do
    it 'calls the delete method on the cloudinary sdk with the given args' do
      expect(Cloudinary::Uploader).to receive(:destroy).with(key)

      subject.delete(key)
    end

    it 'instruments the operation' do
      options = { key: key }
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:delete, options)

      subject.delete(key)
    end
  end

  describe '#delete_prefixed' do
    let(:prefix) { 'some-key-prefix' }

    it 'calls the delete_resources_by_prefix method on the cloudinary sdk' do
      expect(Cloudinary::Api)
        .to receive(:delete_resources_by_prefix)
        .with(prefix)
        .and_return('resources' => [])
      subject.delete_prefixed(prefix)
    end

    it 'instruments the operation' do
      options = { prefix: key }
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:delete_prefixed, options)

      subject.delete_prefixed(key)
    end
  end

  describe '#exist?' do
    it 'calls the resources methods on the cloundinary sdk with the given args' do
      expect(Cloudinary::Api)
        .to receive(:resources_by_ids).with(key).and_return('resources' => [])
      subject.exist?(key)
    end

    it 'returns true if a resource exists with the given key' do
      allow(Cloudinary::Api)
        .to receive(:resources_by_ids).with(key).and_return('resources' => [1])
      expect(subject.exist?(key)).to be true
    end

    it 'returns false if no resource exists with the given key' do
      allow(Cloudinary::Api)
        .to receive(:resources_by_ids).with(key).and_return('resources' => [])
      expect(subject.exist?(key)).to be false
    end

    it 'instruments the operation' do
      options = { key: key }
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:exist?, options)

      subject.exist?(key)
    end
  end

  describe '#url' do
    let(:options) do
      {
        expires_in: 1000,
        disposition: 'inline',
        filename: file,
        content_type: 'image/png'
      }
    end

    let(:signed_options) do
      { resource_type: 'image', type: 'upload', attachment: false }
    end

    it 'calls the private_download_url on the cloudinary sdk' do
      expect(Cloudinary::Utils)
        .to receive(:private_download_url)
        .with(key, 'png', hash_including(signed_options))

      subject.url(key, options)
    end

    context 'raw type assets' do
      before do
        allow(file).to receive(:extension_with_delimiter).and_return('.docx')
      end

      it 'includes the asset format in the public key' do
        expected = signed_options.merge(resource_type: 'raw')
        expect(Cloudinary::Utils)
          .to receive(:private_download_url)
          .with(key + '.docx', 'docx', hash_including(expected))

        subject.url(key, options)
      end
    end

    context 'non raw type assets' do
      it 'does not include the asset format in the public key' do
        expect(Cloudinary::Utils)
          .to receive(:private_download_url)
          .with(key, 'png', hash_including(signed_options))

        subject.url(key, options)
      end
    end

    it 'instruments the operation' do
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:url, key: key)

      subject.url(key, options)
    end
  end

  describe '#url_for_direct_upload' do
    let(:options) do
      {
        expires_in: 1000,
        content_type: 'image/png',
        content_length: 123_456_789,
        checksum: checksum
      }
    end

    let(:signed_options) do
      {
        resource_type: 'auto',
        type: 'upload',
        attachment: false
      }
    end

    it 'calls the private_download_url on the cloudinary sdk' do
      expect(Cloudinary::Utils)
        .to receive(:private_download_url)
        .with(key, '', hash_including(signed_options))
        .and_return("https://cloudinary.api/signed/url/for/#{key}/")

      subject.url_for_direct_upload(key, options)
    end

    it 'instruments the operation' do
      expect_any_instance_of(ActiveStorage::Service)
        .to receive(:instrument).with(:url_for_direct_upload, key: key)

      subject.url_for_direct_upload(key, options)
    end
  end

  describe '#headers_for_direct_upload' do
    it 'returns header info for the content_type and unique id' do
      options = {
        filename: 'some-file-name',
        content_type: 'image/png',
        content_length: 1_234_567,
        checksum: checksum
      }
      exp_result = {
        'Content-Type' => options[:content_type],
        'X-Unique-Upload-Id' => key
      }
      expect(
        subject.headers_for_direct_upload(key, options)
      ).to eq exp_result
    end
  end
end
