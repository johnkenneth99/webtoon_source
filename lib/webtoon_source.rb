# frozen_string_literal: true

require_relative "webtoon_source/version"
require_relative "webtoon_source/asura_scans"
require "faraday"

class WebtoonSource
  class Error < StandardError; end

  attr_accessor :storage_path
  attr_reader :domain

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

    @source = @source_class.new(@domain)

    yield(self) if block_given?
  end

  def domain=(value)
    domain_callback(value)
    @domain = value
  end

  # Checks if a specific chapter for a webtoon has been downloaded.
  def downloaded?(name, chapter)
    path = File.join(@storage_path, name, chapter.to_s)
    Dir.exist?(path) && !Dir.empty?(path)
  end

  def download(params)
    @source.download(params)
  end

  private

  def domain_callback(new_domain)
    @source = @source_class.new(new_domain)
  end
end
