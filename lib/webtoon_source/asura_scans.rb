# frozen_string_literal: true

class WebtoonSource::AsuraScans
  HOST_NAME = "https://asuracomic.net"

  def initialize(host_name = HOST_NAME)
    @conn = Faraday.new(host_name)
  end

  def latest_updates(params = { page: 1 })
    response = @conn.get("/series", params)
    # Capture group 1 - series slug
    # Capture group 2 - anchor tag inner content.
    series_pattern = %r{<a\s+href="series/([^"]+)"[^>]*>(.*?)</a>}

    matches = response.body.scan(series_pattern)

    matches.map do |match|
      slug, anchor_inner_content = match
      _, thumbnail_link = anchor_inner_content.match(/src="([^"]*)"/).to_a

      [slug, thumbnail_link]
    end
  end
end
