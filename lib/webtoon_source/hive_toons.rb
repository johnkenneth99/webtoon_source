# frozen_string_literal: true

# A source implementation for Hive Toons.
class WebtoonSource::HiveToons < WebtoonSource::Base
  BASE_URL = "https://hivetoons.org/"
  MEDIA_STORAGE_URL = "https://storage.hivetoon.com"

  def initialize(base_url = BASE_URL, &block)
    super(base_url, &block)
  end

  def download(chapter_url = nil)
    if chapter_url.nil?
      ensure_present!(:chapter_number, :series_slug, :directory_name)
    else
      path_segments = chapter_url.split("/")

      @series_slug = path_segments[-2]
      @chapter_number = path_segments[-1].split("-").last
    end

    path = File.join(@storage_path, @directory_name, @chapter_number.to_s)

    FileUtils.mkdir_p(path) unless Dir.exist?(path)

    cdn_conn = Faraday.new(MEDIA_STORAGE_URL)

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

  def panels(chapter_url = nil)
    if chapter_url.nil?
      ensure_present!(:series_slug, :chapter_number)
      path = "/series/#{@series_slug}/chapter-#{@chapter_number}"

      response = @conn.get(path)
    else
      response = @conn.get(chapter_url)
      @series_slug = chapter_url.split("/")[-2]
    end

    normalized_slug = @series_slug.gsub(/['"]/, "")
    panel_pattern = %r{#{MEDIA_STORAGE_URL}(/public/upload/series/#{normalized_slug}.+?/page-(\d+).+?\.(webp|jpg|jpeg|png))} # rubocop:disable Layout/LineLength

    response.body.scan(panel_pattern).uniq
  end

  def chapters(series_url = nil) # rubocop:disable Metrics/AbcSize
    if series_url.nil?
      ensure_present!(:series_slug)

      response = @conn.get("/comics/#{@series_slug}")
    else
      response = @conn.get(series_url)
      @series_slug = series_url.split("/").last
    end

    doc = Nokogiri::HTML(response.body)

    island = doc.at_css('astro-island[opts*="SeriesChaptersPanelIsland"]')

    data = JSON.parse(island["props"])
    normalized_data = WebtoonSource::Helpers::Transformers.normalize_astro_island_props(data)

    chapter_list = normalized_data.dig("post", "chapters")

    return [] if chapter_list.nil?

    mapped_chapters = chapter_list.map do |chapter|
      chapter_number = chapter["number"].to_s
      chapter_path = ["/comics", @series_slug, "chapter", chapter_number].join("/")

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
end
