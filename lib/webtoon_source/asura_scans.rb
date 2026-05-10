# frozen_string_literal: true

class WebtoonSource::AsuraScans
  attr_accessor :storage_path, :series_slug, :domain_name, :chapter_number

  DEFAULT_STORAGE_PATH = File.join(Dir.home, "webtoon_source")

  SERIES_NAME_PATTERN = /(.+)-/

  BASE_URL = "https://asurascans.com"
  CDN_URL = "https://cdn.asurascans.com"

  def initialize(base_url = BASE_URL)
    @base_url = base_url
    @storage_path = DEFAULT_STORAGE_PATH

    @conn = Faraday.new(@base_url) do |config|
      config.headers["User-Agent"] = "WebtoonSource/#{WebtoonSource::VERSION}"

      config.response :follow_redirects
      config.response :json, content_type: /\bjson$/
      config.response :xml, content_type: /\bxml$/

      config.adapter Faraday.default_adapter
    end

    yield(self) if block_given?
  end

  # Sets the series slug for the current instance.
  # @param slug [String] the series slug to set.
  # @return [self].
  def series(slug)
    @series_slug = slug
    self
  end

  # Sets the chapter number for the current instance.
  # @param number [String, Integer] the chapter number to set.
  # @return [self].
  def chapter(number)
    @chapter_number = number
    self
  end

  # Sets the storage path for the current instance.
  # @param path [String] the storage path to set.
  # @return [self].
  def storage(path)
    @storage_path = path
    self
  end

  # Sets the directory name for the current instance.
  # @param name [String] the directory name to set.
  # @return [self].
  def directory(name)
    @directory_name = name
    self
  end

  # Downloads the panels for the current series and chapter.
  # @return [Array<String>] the list of panel image paths.
  # @raise [StandardError] if chapter_number, series_slug, or directory_name is not set.
  def download
    raise StandardError, "Chapter number must be set." if @chapter_number.nil?
    raise StandardError, "Series slug must be set." if @series_slug.nil?
    raise StandardError, "Directory name must be set." if @directory_name.nil?

    path = File.join(@storage_path, @directory_name, @chapter_number.to_s)

    FileUtils.mkdir_p(path) unless Dir.exist?(path)

    cdn_conn = Faraday.new(CDN_URL)

    panels.each do |panel_path|
      order, extension = panel_path.split("/").last.split(".")
      panel_name = "#{order.rjust(2, "0")}.#{extension}"

      panel_storage_path = File.join(path, panel_name)

      File.open(panel_storage_path, "wb") do |f|
        cdn_conn.get(panel_path) do |response|
          response.options.on_data = proc { |chunk, _size| f.write chunk }
        end
      end
    end
  end

  # Retrieves the list of panel image paths for the current series and chapter.
  # @return [Array<String>] the list of panel image paths.
  # @raise [StandardError] if series_slug or chapter_number is not set.
  def panels
    raise StandardError, "Series slug must be set." if @series_slug.nil?
    raise StandardError, "Chapter number must be set." if @chapter_number.nil?

    path = "/comics/#{@series_slug}/chapter/#{@chapter_number}"

    response = @conn.get(path)

    panel_pattern = %r{https://cdn.asurascans.com/asura-images/chapters/.+?/#{@chapter_number}/.+?\.webp}

    response.body.scan(panel_pattern).uniq.map { |link| URI(link).path }
  end

  # Retrieves the list of chapters for the current series.
  # @param chapter_url [String, nil] an optional URL to fetch chapters from.
  # @return [Array<Hash>] the list of chapters with metadata.
  # @raise [StandardError] if series_slug is not set and no URL is provided.
  def chapters(chapter_url = nil) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    if chapter_url.nil?
      raise StandardError, "Series slug must be set." if @series_slug.nil?

      response = @conn.get("/comics/#{@series_slug}")
    else
      response = @conn.get(chapter_url)
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
