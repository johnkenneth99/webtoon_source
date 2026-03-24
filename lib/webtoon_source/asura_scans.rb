# frozen_string_literal: true

class WebtoonSource::AsuraScans
  attr_accessor :storage_path

  SERIES_NAME_PATTERN = /(.+)-/
  PANEL_PATTERN = %r{{\\"order\\":(\d+),\\"url\\":\\"(https://gg.asuracomic.net/storage/media/\d+/conversions/[^"]+)\\"}}

  PANEL_ORDER = 1
  PANEL_LINK = 0

  def initialize(domain)
    @conn = Faraday.new(domain) do |config|
      config.headers["User-Agent"] = "WebtoonSource/#{WebtoonSource::VERSION}"
    end

    yield(self) if block_given?
  end

  def latest_updates(params = { page: 1 })
    response = @conn.get("/comics", params)
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
    panels, chapter, directory = params.values_at(:panels, :chapter, :directory)

    chapter_storage_path = File.join(@storage_path, directory, chapter.to_s)

    FileUtils.mkdir_p(chapter_storage_path) unless Dir.exist?(chapter_storage_path)

    panel_link = URI(panels.first[PANEL_LINK])
    panel_domain = "#{panel_link.scheme}://#{panel_link.hostname}"

    media_conn = Faraday.new(panel_domain)

    panels.each do |link, order|
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

  def panels(chapter_slug)
    response = @conn.get(chapter_slug)
    chapter_number = chapter_slug.match(%r{chapter/(.+)}).to_a.last

    panel_pattern = %r{(https://cdn.asurascans.com/asura-images/chapters/.+?/#{chapter_number}/(\d+)\.webp)}

    panels = response.body.scan(panel_pattern).uniq
    panels.sort { |a, b| a[PANEL_ORDER].to_i <=> b[PANEL_ORDER].to_i }
  end

  def chapters(slug)
    response = @conn.get("comics/#{slug}")
    chapter_pattern = %r{<a\shref="/comics/#{slug}/chapter/([^"]+)}

    chapters = response.body.scan(chapter_pattern).flatten.uniq

    sorted = chapters.sort { |a, b| a.to_i <=> b.to_i }

    sorted.map do |chapter|
      chapter_slug = "comics/#{slug}/chapter/#{chapter}"

      { chapter_slug:, chapter_number: chapter }
    end
  end

  def search(params)
    title, comic_type = params.values_at(:title, :comic_type)

    search_params = {
      q: title,
      type: comic_type
    }

    response = @conn.get("browse", search_params)

    slug_pattern = %r{<a\s+href="/comics/([^"]+)"}
    slugs = response.body.scan(slug_pattern).flatten.uniq

    slugs.first
  end
end
