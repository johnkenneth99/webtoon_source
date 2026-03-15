# frozen_string_literal: true

require_relative "webtoon_source/version"
require_relative "webtoon_source/asura_scans"
require_relative "webtoon_source/jikan"
require "faraday"
require "fileutils"

# This is the main namespace for WebtoonSource.
class WebtoonSource
  class Error < StandardError; end
  attr_reader :storage_path, :domain

  DEFAULT_STORAGE_PATH = File.join(Dir.home, "webtoon_source")

  DOMAINS = {
    asura_scans: "https://asuracomic.net",
    manhuaus: "https://manhuaus.com/"
  }.freeze

  SOURCES = {
    asura_scans: WebtoonSource::AsuraScans
  }.freeze

  def initialize(platform = :asura_scans)
    @storage_path = DEFAULT_STORAGE_PATH

    @domain = DOMAINS[platform]
    @source_class = SOURCES[platform] || raise(WebtoonSource::Error, "Unknown platform: #{platform}")

    @source = @source_class.new(@domain) do |config|
      config.storage_path = @storage_path
    end

    yield(self) if block_given?
  end

  def domain=(value)
    domain_callback(value)
    @domain = value
  end

  def storage_path=(value)
    storage_path_callback(value)
    @storage_path = value
  end

  # Checks if a specific chapter for a webtoon has been downloaded.
  def downloaded?(chapter_path)
    path = File.join(@storage_path, chapter_path)
    Dir.exist?(path) && !Dir.empty?(path)
  end

  def download(params)
    @source.download(params)
  end

  def panels(chapter_slug)
    @source.panels(chapter_slug)
  end

  def chapters(slug)
    @source.chapters(slug)
  end

  def metadata(mal_id)
    jikan_service.manga_full_by_id(mal_id)
  end

  def search(params)
    jikan_service.search(params)
  end

  private

  def domain_callback(new_domain)
    @source = @source_class.new(new_domain)
  end

  def storage_path_callback(new_storage_path)
    @source = @source_class.new(@domain) do |config|
      config.storage_path = new_storage_path
    end
  end

  def jikan_service
    service ||= Jikan.new
    service
  end
end
