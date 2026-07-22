# frozen_string_literal: true

# A source implementation for Asura Scans.
class WebtoonSource::AsuraScans < WebtoonSource::Base
  BASE_URL = "https://asurascans.com"

  def initialize(base_url = BASE_URL, &block)
    super(base_url, &block)
  end

  def download(chapter_url = nil)
    if chapter_url.nil?
      ensure_present!(:chapter_number, :series_slug, :directory_name)
    else
      path_segments = chapter_url.delete_suffix("/").split("/")

      @series_slug = path_segments[-3]
      @chapter_number = path_segments.last
      @directory_name = @series_slug.gsub("-", "_")
    end

    chapter_directory = File.join(@storage_path, @directory_name, @chapter_number.to_s)

    FileUtils.mkdir_p(chapter_directory) unless Dir.exist?(chapter_directory)

    download_panels(panels, chapter_directory)
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

    build_panel_result(doc, index_attribute: "data-page-index")
  end

  def chapters(series_url = nil)
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
    normalized_data = WebtoonSource::Helpers::Transformers.normalize_astro_island_props(data)
    chapter_list = normalized_data["chapters"]

    return [] if chapter_list.nil?

    build_chapters(chapter_list, path_prefix: "/comics")
  end

  private

  def finalize_chapter_fields(chapter_fields)
    chapter_fields.merge(slug: "chapter/#{chapter_fields[:number]}")
  end
end
