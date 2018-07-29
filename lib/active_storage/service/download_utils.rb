require 'net/http'
require 'openssl'

module DownloadUtils
  def stream_download(source, chunk_size = 5_242_880)
    url = URI.parse(source)
    http, req = setup_connection(url)

    content_length = http.request_head(url).content_length
    upper_limit = content_length + (content_length % chunk_size)
    offset = 0

    http.start do |agent|
      while offset < upper_limit
        lim = (offset + chunk_size)
        # QUESTION: is it relevant to set the last chunk
        # to the exact remaining bytes
        # lim = content_length if lim > content_length
        req.range = (offset..lim)

        chunk = agent.request(req).body
        yield chunk.force_encoding(Encoding::BINARY)

        offset += chunk_size + 1
      end
    end
  end

  def download_range(source, range)
    url = URI.parse(source)
    http, req = setup_connection(url)
    req.range = range

    chunk = http.start { |agent| agent.request(req).body }
    chunk.force_encoding(Encoding::BINARY)
  end

  private

  def setup_connection(url)
    http = Net::HTTP.new(url.host, url.port)
    req = Net::HTTP::Get.new(url.request_uri)

    if url.port == 443
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    [http, req]
  end
end
