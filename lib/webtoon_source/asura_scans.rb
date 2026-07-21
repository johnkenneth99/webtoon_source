# frozen_string_literal: true

# A source implementation for Asura Scans.
class WebtoonSource::AsuraScans < WebtoonSource::Base
  # The base URL for the Asura Scans website.
  BASE_URL = "https://asurascans.com"
  # The base URL for the Asura Scans CDN.
  CDN_URL = "https://cdn.asurascans.com"

  # Initializes a new instance of the Asura Scans source.
  #
  # @param base_url [String] the base URL of the source.
  # @yield [self] yields the instance to an optional block for configuration.
  def initialize(base_url = BASE_URL, &block)
    super(base_url, &block)
  end

  # Downloads the panels for the current series and chapter.
  #
  # @return [Array<String>] the list of panel image paths.
  # @raise [ArgumentError] if chapter_number, series_slug, or directory_name is not set.
  def download
    ensure_present!(:chapter_number, :series_slug, :directory_name)

    path = File.join(@storage_path, @directory_name, @chapter_number.to_s)

    FileUtils.mkdir_p(path) unless Dir.exist?(path)

    cdn_conn = Faraday.new(CDN_URL)

    panels.each_with_index do |panel, index|
      panel_path, extension = panel
      panel_name = "#{index.to_s.rjust(2, "0")}.#{extension}"

      panel_storage_path = File.join(path, panel_name)

      File.open(panel_storage_path, "wb") do |f|
        cdn_conn.get(panel_path) do |response|
          response.options.on_data = proc { |chunk, _size| f.write chunk }
        end
      end
    end
  end

  def panels(chapter_url = nil)
    if chapter_url.nil?
      ensure_present!(:series_slug, :chapter_number)
      path = "/comics/#{@series_slug}/chapter/#{@chapter_number}"

      response = @conn.get(path)
    else
      response = @conn.get(chapter_url)
      segments = chapter_url.delete_suffix("/").split("/")
      @series_slug = segments[-3]
    end

    doc = Nokogiri::HTML(response.body)
    base_url = nil

    panel_list = doc.css("img[src][data-page-index]").map do |img|
      panel_uri = URI.parse(img["src"])

      base_url = "#{panel_uri.scheme}://#{panel_uri.host}" if base_url.nil?
      path = panel_uri.path

      Panel.new(
        path:,
        order: img["data-page-index"],
        file_extension: File.extname(path).delete_prefix(".")
      )
    end

    PanelResult.new(
      base_url:,
      panel_list:
    )
  end

  def chapters(series_url = nil) # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity
    if series_url.nil?
      ensure_present!(:series_slug)
      response = @conn.get("/comics/#{@series_slug}")
    else
      response = @conn.get(series_url)
      @series_slug = series_url.delete_suffix("/").split("/").last
    end

    doc = Nokogiri::HTML(response.body)

    # Get chapter list island
    island = doc.at_css('astro-island[opts*="ChapterListReact"]')

    data = JSON.parse(island["props"])
    chapter_list = normalize(data)["chapters"]

    return [] if chapter_list.nil?

    mapped_chapters = chapter_list.map do |chapter|
      chapter_fields = {
        id: nil,
        slug: nil,
        title: nil,
        number: nil,
        is_locked: nil,
        metadata: {}
      }

      chapter.each do |key, value|
        new_key = WebtoonSource::Helpers::String.snake_case(key).to_sym

        if ALLOWED_CHAPTER_FIELDS.include?(key)
          chapter_fields[new_key] = value
        else
          chapter_fields[:metadata][new_key] = value
        end
      end

      chapter_fields[:number] = chapter_fields [:number].to_s
      chapter_fields[:slug] = "chapter/#{chapter_fields[:number]}"

      Chapter.new(
        **chapter_fields,
        series_slug: @series_slug,
        path: ["/comics", @series_slug, chapter_fields[:slug]].join("/")
      )
    end

    mapped_chapters.sort_by { |chapter| -chapter.number.to_f }
  end

  private

  def normalize(obj) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    if obj.is_a?(Array) && obj.length == 2 && [0, 1].include?(obj[0])
      normalize(obj[1])
    elsif obj.is_a?(Array)
      obj.map { |item| normalize(item) }
    elsif obj.is_a?(Hash)
      obj.transform_values { |v| normalize(v) }
    else
      obj
    end
  end
end
