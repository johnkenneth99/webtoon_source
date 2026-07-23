# frozen_string_literal: true

# A source implementation for Hive Toons.
class WebtoonSource::KenComics < WebtoonSource::Base
  BASE_URL = "https://kencomics.com/"

  def initialize(base_url = BASE_URL, &block)
    super(base_url, &block)
  end

  def download(chapter_url = nil)
    if chapter_url.nil?
      ensure_present!(:chapter_number, :series_slug, :directory_name)
    else
      path_segments = chapter_url.delete_suffix("/").split("/")

      @series_slug = path_segments[-2]
      @chapter_number = path_segments[-1].split("-").last
      @directory_name = @series_slug.gsub("-", "_")
    end

    chapter_directory = File.join(@storage_path, @directory_name, @chapter_number.to_s)

    FileUtils.mkdir_p(chapter_directory) unless Dir.exist?(chapter_directory)

    download_panels(panels, chapter_directory)
  end

  def panels(chapter_url = nil)
    if chapter_url.nil?
      ensure_present!(:series_slug, :chapter_number)
      path = "/series/#{@series_slug}/chapter-#{@chapter_number}"

      response = @conn.get(path)
    else
      response = @conn.get(chapter_url)
      @series_slug = chapter_url.delete_suffix("/").split("/")[-2]
    end

    doc = Nokogiri::HTML(response.body)

    build_panel_result(doc, index_attribute: "data-reader-index")
  end

  def chapters(series_url = nil)
    if series_url.nil?
      ensure_present!(:series_slug)
      response = @conn.get("/series/#{@series_slug}")
    else
      response = @conn.get(series_url)
      @series_slug = series_url.delete_suffix("/").split("/").last
    end

    doc = Nokogiri::HTML(response.body)
    island = doc.at_css('astro-island[opts*="SeriesChaptersPanelIsland"]')

    data = JSON.parse(island["props"])
    normalized_data = WebtoonSource::Helpers::Transformers.normalize_astro_island_props(data)

    chapter_list = normalized_data["initialChap"]

    return [] if chapter_list.nil?

    build_chapters(chapter_list, path_prefix: "/series")
  end
end
