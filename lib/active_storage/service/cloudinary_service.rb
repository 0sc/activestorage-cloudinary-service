require 'cloudinary'
require_relative 'download_utils'

module ActiveStorage
  # Wraps the Cloudinary as an Active Storage service.
  # See ActiveStorage::Service for the generic API documentation that applies to all services.
  class Service::CloudinaryService < Service
    include DownloadUtils

    # FIXME: implement setup for private resource type
    # FIXME: allow configuration via cloudinary url
    def initialize(cloud_name:, api_key:, api_secret:, **options)
      options.merge!(
        cloud_name: cloud_name,
        api_key: api_key,
        api_secret: api_secret
      )
      Cloudinary.config(options)
      # Cloudinary.config_from_url(url)
    end

    def upload(key, io, checksum: nil, **)
      instrument :upload, key: key, checksum: checksum do
        Cloudinary::Uploader.upload(io, public_id: key, resource_type: 'auto')
      end
    end

    # Return the content of the file at the +key+.
    def download(key, &block)
      source = cloudinary_url_for_key(key)

      if block_given?
        instrument :streaming_download, key: key do
          stream_download(source, &block)
        end
      else
        instrument :download, key: key do
          Cloudinary::Downloader.download(source)
        end
      end
    end

    # Return the partial content in the byte +range+ of the file at the +key+.
    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        source = cloudinary_url_for_key(key)
        download_range(source, range)
      end
    end

    # Delete the file at the +key+.
    def delete(key)
      instrument :delete, key: key do
        delete_resource_with_public_id(key)
      end
    end

    # Delete files at keys starting with the +prefix+.
    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        Cloudinary::Api.delete_resources_by_prefix(prefix)
      end
    end

    # Return +true+ if a file exists at the +key+.
    def exist?(key)
      instrument :exist?, key: key do
        resource_exists_with_public_id?(key)
      end
    end

    # Returns a signed, temporary URL for the file at the +key+. The URL will be valid for the amount
    # of seconds specified in +expires_in+. You must also provide the +disposition+ (+:inline+ or +:attachment+),
    # +filename+, and +content_type+ that you wish the file to be served with on request.
    def url(key, expires_in:, disposition:, filename:, content_type:)
      instrument :url, key: key do
        options = {
          expires_in: expires_in,
          content_type: content_type,
          disposition: disposition,
          filename: filename
        }
        signed_download_url_for_public_id(key, options)
      end
    end

    # Returns a signed, temporary URL that a direct upload file can be PUT to on the +key+.
    # The URL will be valid for the amount of seconds specified in +expires_in+.
    # You must also provide the +content_type+, +content_length+, and +checksum+ of the file
    # that will be uploaded. All these attributes will be validated by the service upon upload.
    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
      instrument :url_for_direct_upload, key: key do
        options = {
          expires_in: expires_in,
          content_type: content_type,
          content_length: content_length,
          checksum: checksum,
          resource_type: 'auto'
        }

        # FIXME: Cloudinary Ruby SDK does't expose an api for signed upload url
        # The expected url is similar to the private_download_url
        # with download replaced with upload
        signed_download_url_for_public_id(key, options)
          .sub(/download/, 'upload')
      end
    end

    # Returns a Hash of headers for +url_for_direct_upload+ requests.
    def headers_for_direct_upload(key, filename:, content_type:, content_length:, checksum:)
      { 'Content-Type' => content_type, 'X-Unique-Upload-Id' => key }
    end

    private

    def resource_exists_with_public_id?(public_id)
      !find_resource_with_public_id(public_id).empty?
    end

    def find_resource_with_public_id(public_id)
      Cloudinary::Api.resources_by_ids(public_id).fetch('resources')
    end

    def delete_resource_with_public_id(public_id)
      Cloudinary::Uploader.destroy(public_id)
    end

    def signed_download_url_for_public_id(public_id, options)
      extension = resource_format(options[:filename])
      options[:resource_type] ||= resource_type(extension)

      Cloudinary::Utils.private_download_url(
        finalize_public_id(public_id, extension, options[:resource_type]),
        extension,
        signed_url_options(options)
      )
    end

    # TODO: for assets of type raw,
    # cloudinary request the extension to be part of the public_id
    def finalize_public_id(public_id, extension, resource_type)
      return public_id unless resource_type == 'raw'
      public_id + '.' + extension
    end

    def signed_url_options(options)
      {
        resource_type: (options[:resource_type] || 'image'),
        type: (options[:type] || 'upload'),
        attachment: (options[:disposition]&.to_sym == :attachment),
        expires_at: (Time.now + options[:expires_in])
      }
    end

    def resource_format(filename)
      extension = filename&.extension_with_delimiter || ''
      extension.sub('.', '')
    end

    def resource_type(extension)
      Cloudinary::Utils.resource_type_for_format(extension)
    end

    def cloudinary_url_for_key(key)
      Cloudinary::Utils.cloudinary_url(key, sign_url: true)
    end
  end
end
