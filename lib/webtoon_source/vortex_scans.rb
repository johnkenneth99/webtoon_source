# frozen_string_literal: true

# A source implementation for Vortex Scans.
class WebtoonSource::VortexScans < WebtoonSource::Base
  # The base URL for the Vortex Scans website.
  BASE_URL = "https://vortexscans.org"
  # The base URL for the Vortex Scans CDN.
  CDN_URL = "https://storage.vortexscans.org"

  # Initializes a new instance of the Vortex Scans source.
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

    panels.each do |panel|
      panel_path, order, file_extension = panel
      # Format: "0001", "0002", etc.
      panel_name = "#{order.slice(2..-1)}.#{file_extension}"

      panel_storage_path = File.join(path, panel_name)

      File.open(panel_storage_path, "wb") do |f|
        cdn_conn.get(panel_path) do |response|
          response.options.on_data = proc { |chunk, _size| f.write chunk }
        end
      end
    end
  end

  # TODO: Add support for full chapter_url as argument.

  # Retrieves the list of panel image paths for the current series and chapter.
  #
  # @return [Array<String>] the list of panel image paths.
  # @raise [ArgumentError] if series_slug or chapter_number is not set.
  def panels
    ensure_present!(:series_slug, :chapter_number)

    path = "/series/#{@series_slug}/chapter-#{@chapter_number}"

    response = @conn.get(path)

    normalized_slug = @series_slug.gsub(/['"]/, "")
    panel_pattern = %r{#{CDN_URL}(/upload/series/#{normalized_slug}.+?/page-(\d+).+?\.(webp|jpg|jpeg|png))}

    response.body.scan(panel_pattern).uniq
  end

  # Retrieves the list of chapters for the current series.
  #
  # @param series_url [String, nil] an optional URL to fetch chapters from.
  # @return [Array<Hash>] the list of chapters with metadata.
  # @raise [ArgumentError] if series_slug is not set and no URL is provided.
  def chapters(series_url = nil) # rubocop:disable Metrics/AbcSize
    if series_url.nil?
      ensure_present!(:series_slug)

      response = @conn.get("/series/#{@series_slug}")
    else
      response = @conn.get(series_url)
      @series_slug = series_url.split("/").last
    end

    doc = Nokogiri::HTML(response.body)
    island = doc.at_css('astro-island[opts*="SeriesChaptersPanelIsland"]')

    data = JSON.parse(island["props"])
    chapter_list = normalize(data).dig("post", "chapters")

    return [] if chapter_list.nil?

    mapped_chapters = chapter_list.map do |chapter|
      chapter_number = chapter["number"].to_s
      chapter_path = ["/series", @series_slug, chapter_number].join("/")

      metadata = chapter.except(chapter_number).transform_keys { |key| WebtoonSource::Helpers::String.snake_case(key).to_sym }

      {
        chapter_number:,
        chapter_path:,
        series_slug: @series_slug,
        metadata:
      }
    end

    mapped_chapters.sort_by { |chapter| -chapter[:chapter_number].to_f }
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
