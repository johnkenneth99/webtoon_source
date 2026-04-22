# frozen_string_literal: true

class WebtoonSource::AsuraScans
  attr_accessor :storage_path

  SERIES_NAME_PATTERN = /(.+)-/

  def initialize(domain)
    @domain = domain
    @conn = Faraday.new(domain) do |config|
      config.headers["User-Agent"] = "WebtoonSource/#{WebtoonSource::VERSION}"

      config.response :follow_redirects
      config.response :json, content_type: /\bjson$/
      config.response :xml, content_type: /\bxml$/

      config.adapter Faraday.default_adapter
    end

    yield(self) if block_given?
  end

  def download(params) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    base_url, panels, chapter, directory = params.values_at(:base_url, :panels, :chapter, :directory)

    chapter_storage_path = File.join(@storage_path, directory, chapter.to_s)

    FileUtils.mkdir_p(chapter_storage_path) unless Dir.exist?(chapter_storage_path)

    media_conn = Faraday.new(base_url)

    panels.each_with_index do |panel_path, order|
      panel_name = "#{order.to_s.rjust(2, "0")}.webp"

      panel_storage_path = File.join(chapter_storage_path, panel_name)

      File.open(panel_storage_path, "wb") do |f|
        media_conn.get(panel_path) do |response|
          response.options.on_data = proc { |chunk, _size| f.write chunk }
        end
      end
    end
  end

  def panels(chapter_path)
    response = @conn.get(chapter_path)

    chapter_number = chapter_path.match(%r{chapter/(.+)}).to_a.last
    panel_pattern = %r{https://cdn.asurascans.com/asura-images/chapters/.+?/#{chapter_number}/.+?\.webp}

    panel_urls = response.body.scan(panel_pattern).uniq
    panel_url = URI(panel_urls.first)

    {
      base_url: "#{panel_url.scheme}://#{panel_url.hostname}",
      panels: panel_urls.map { |link| URI(link).path }
    }
  end

  def chapters(slug) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    response = @conn.get(slug)
    # slug with hash path
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
