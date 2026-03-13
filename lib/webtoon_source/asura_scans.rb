# frozen_string_literal: true

class WebtoonSource::AsuraScans
  attr_accessor :storage_path

  SERIES_NAME_PATTERN = /(.+)-/
  PANEL_PATTERN = %r{{\\"order\\":(\d+),\\"url\\":\\"(https://gg.asuracomic.net/storage/media/\d+/conversions/[^"]+)\\"}}

  PANEL_ORDER = 0
  PANEL_LINK = 1

  def initialize(domain)
    @conn = Faraday.new(domain)

    yield(self) if block_given?
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

  def download(params) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    panels, chapter, name = params.values_at(:panels, :chapter, :name)

    chapter_storage_path = File.join(@storage_path, name, chapter.to_s)

    FileUtils.mkdir_p(chapter_storage_path) unless Dir.exist?(chapter_storage_path)

    panel_link = URI(panels.first[PANEL_LINK])
    panel_domain = "#{panel_link.scheme}://#{panel_link.hostname}"

    media_conn = Faraday.new(panel_domain)

    panels.each do |order, link|
      panel_path = URI(link).path
      panel_name = "#{order.rjust(2, "0")}.webp"

      panel_storage_path = File.join(chapter_storage_path, panel_name)

      File.open(panel_storage_path, "wb") do |f|
        media_conn.get(panel_path) do |response|
          response.options.on_data = proc { |chunk, _size| f.write chunk }
        end
      end
    end
  end

  def extract_series_name(slug)
    slug.match(SERIES_NAME_PATTERN).to_a.last
  end

  def panels(params)
    slug, chapter = params.values_at(:slug, :chapter)
    chapter_slug = File.join("series", slug, "chapter", chapter.to_s)

    response = @conn.get(chapter_slug)

    panels = response.body.scan(PANEL_PATTERN).uniq
    panels.sort { |a, b| a[PANEL_ORDER].to_i <=> b[PANEL_ORDER].to_i }
  end
end
