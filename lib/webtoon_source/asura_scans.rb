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

  # Retrieves the list of panel image paths for the current series and chapter.
  #
  # @return [Array<String>] the list of panel image paths.
  # @raise [ArgumentError] if series_slug or chapter_number is not set.
  def panels
    ensure_present!(:series_slug, :chapter_number)

    path = "/comics/#{@series_slug}/chapter/#{@chapter_number}"

    response = @conn.get(path)

    panel_pattern = %r{https://cdn.asurascans.com(/asura-images/chapters/.+?/#{@chapter_number}/.+?\.(webp|jpg|jpeg|png))}

    response.body.scan(panel_pattern).uniq
  end

  # Retrieves the list of chapters for the current series.
  #
  # @param chapter_url [String, nil] an optional URL to fetch chapters from.
  # @return [Array<Hash>] the list of chapters with metadata.
  # @raise [ArgumentError] if series_slug is not set and no URL is provided.
  def chapters(chapter_url = nil) # rubocop:disable Metrics/AbcSize
    if chapter_url.nil?
      ensure_present!(:series_slug)

      response = @conn.get("/comics/#{@series_slug}")
    else
      response = @conn.get(chapter_url)
      @series_slug = chapter_url.split("/").last
    end

    new_slug = response.env.url.path
    doc = Nokogiri::HTML(response.body)

    # Get chapter list island
    island = doc.at_css('astro-island[opts*="ChapterListReact"]')
    island = doc.at_css('astro-island[component-url*="ChapterListReact"]') if island.nil?

    data = JSON.parse(island["props"])

    chapter_hash = {}

    normalize(data)["chapters"].each do |item|
      key = item["number"].to_s
      chapter_hash[key] = item.except("number")
    end

    chapter_links = doc.css("a[href*='#{new_slug}/chapter']").map { |link| link["href"] }.uniq

    mapped_doc = chapter_links.map do |link|
      chapter_number = link.split("/").last

      {
        chapter_number:,
        chapter_path: link,
        metadata: chapter_hash[chapter_number]
      }
    end

    mapped_doc.sort_by { |chapter| -chapter[:chapter_number].to_f }
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
