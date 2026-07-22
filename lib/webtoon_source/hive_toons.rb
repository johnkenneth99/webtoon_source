# frozen_string_literal: true

# A source implementation for Hive Toons.
class WebtoonSource::HiveToons < WebtoonSource::Base
  BASE_URL = "https://hivetoons.org/"

  def initialize(base_url = BASE_URL, &block)
    super(base_url, &block)
  end

  def download(chapter_url = nil) # rubocop:disable Metrics/AbcSize
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

    panel_result = panels
    cdn_conn = Faraday.new(panel_result.base_url)

    panel_result.panel_list.each do |panel|
      panel_name = [panel.order.rjust(2, "0"), ".", panel.file_extension].join
      panel_directory = File.join(chapter_directory, panel_name)

      File.open(panel_directory, "wb") do |f|
        cdn_conn.get(panel.path) do |response|
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
      @series_slug = chapter_url.delete_suffix("/").split("/")[-2]
    end

    doc = Nokogiri::HTML(response.body)
    base_url = nil

    panel_list = doc.css("img[src][data-reader-index]").map do |img|
      panel_uri = URI.parse(img["src"])

      base_url = "#{panel_uri.scheme}://#{panel_uri.host}" if base_url.nil?
      path = panel_uri.path

      Panel.new(
        path:,
        order: img["data-reader-index"],
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

      Chapter.new(
        **chapter_fields,
        series_slug: @series_slug,
        path: ["/series", @series_slug, chapter_fields[:slug]].join("/")
      )
    end

    mapped_chapters.sort_by { |chapter| -chapter.number.to_f }
  end
end
