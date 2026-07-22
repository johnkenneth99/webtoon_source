# frozen_string_literal: true

# The base class for all webtoon sources.
# It provides a common interface and shared functionality for fetching
# webtoon data from various platforms.
class WebtoonSource::Base
  attr_accessor :storage_path, :series_slug, :domain_name, :chapter_number

  # The default path where webtoon panels are stored.
  DEFAULT_STORAGE_PATH = File.join(Dir.home, "webtoon_source")
  ALLOWED_CHAPTER_FIELDS = %w[isLocked id number slug title].freeze

  Panel = Data.define(:path, :order, :file_extension)
  PanelResult = Data.define(:base_url, :panel_list)
  Chapter = Data.define(:is_locked, :id, :number, :slug, :title, :series_slug, :path, :metadata)

  # Initializes a new instance of the webtoon source.
  #
  # @param base_url [String] the base URL of the webtoon source.
  # @yield [self] yields the instance to an optional block for configuration.
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
  # @return [self] the current instance.
  def series(slug)
    @series_slug = slug.delete_suffix("/")
    self
  end

  # Sets the chapter number for the current instance.
  # @param number [String, Integer] the chapter number to set.
  # @return [self] the current instance.
  def chapter(number)
    @chapter_number = number
    self
  end

  # Sets the storage path for the current instance.
  # @param path [String] the storage path to set.
  # @return [self] the current instance.
  def storage(path)
    @storage_path = path
    self
  end

  # Sets the directory name for the current instance.
  # @param name [String] the directory name to set.
  # @return [self] the current instance.
  def directory(name)
    @directory_name = name
    self
  end

  # Downloads the panels for the current series and chapter.
  # This method must be implemented by subclasses.
  #
  # @abstract
  # @raise [NotImplementedError] if the subclass does not implement this method.
  def download
    raise NotImplementedError, "#{self.class} must implement #download"
  end

  # Retrieves the list of panel details for the current series and chapter.
  # This method must be implemented by subclasses.
  #
  # @abstract
  # @param chapter_url [String] the url of the chapter to get the panels.
  # @return [PanelResult] the base URL and ordered list of panels for the chapter.
  # @raise [NotImplementedError] if the subclass does not implement this method.
  def panels
    raise NotImplementedError, "#{self.class} must implement #panels"
  end

  # Retrieves the list of chapters for the current series.
  # This method must be implemented by subclasses.
  #
  # @abstract
  # @param chapter_url [String, nil] an optional URL to fetch chapters from.
  # @return [Array<Hash>] the list of chapters with metadata.
  # @raise [NotImplementedError] if the subclass does not implement this method.
  def chapters(chapter_url = nil)
    raise NotImplementedError, "#{self.class} must implement #chapters"
  end

  # Ensures that the specified instance variables are set.
  #
  # @param attributes [Array<Symbol>] the names of the instance variables to check.
  # @raise [ArgumentError] if any of the specified instance variables are nil.
  def ensure_present!(*attributes)
    attributes.each do |attribute|
      raise ArgumentError, "@#{attribute} must be set." if instance_variable_get("@#{attribute}").nil?
    end
  end

  # Downloads each panel in the given result and writes it to the given directory.
  #
  # @param panel_result [PanelResult] the base URL and ordered list of panels to download.
  # @param chapter_directory [String] the directory to write the downloaded panels to.
  def download_panels(panel_result, chapter_directory)
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

  # Builds a PanelResult from a parsed chapter page.
  #
  # @param doc [Nokogiri::HTML::Document] the parsed chapter page.
  # @param index_attribute [String] the image attribute holding the panel's reader order.
  # @return [PanelResult] the CDN base URL and ordered list of panels found in the document.
  def build_panel_result(doc, index_attribute:)
    base_url = nil

    panel_list = doc.css("img[src][#{index_attribute}]").map do |img|
      panel_uri = URI.parse(img["src"])

      base_url = "#{panel_uri.scheme}://#{panel_uri.host}" if base_url.nil?
      path = panel_uri.path

      Panel.new(
        path:,
        order: img[index_attribute],
        file_extension: File.extname(path).delete_prefix(".")
      )
    end

    PanelResult.new(
      base_url:,
      panel_list:
    )
  end
end
