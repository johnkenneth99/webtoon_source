# frozen_string_literal: true

require_relative "webtoon_source/version"
require_relative "webtoon_source/base"

Dir.glob(File.join(__dir__, "webtoon_source", "**", "*.rb")).sort.each do |file|
  require_relative file
end

require "faraday"
require "faraday/xml"
require "faraday/follow_redirects"

require "nokogiri"

require "fileutils"
require "json"

# This is the main namespace for WebtoonSource.
class WebtoonSource
  extend Forwardable

  class Error < StandardError; end

  def_delegators :@source, :download, :panels, :chapters, :series, :chapter, :directory

  SOURCES = {
    asura_scans: AsuraScans,
    vortex_scans: VortexScans,
    hive_toons: HiveToons,
    kayn_scan: KaynScan,
    ken_comics: KenComics
  }.freeze

  def initialize(platform = :asura_scans)
    @source_class = SOURCES[platform] || raise(Error, "Unknown platform: #{platform}")
    @source = @source_class.new
  end

  # Checks if a specific chapter for a webtoon has been downloaded.
  def downloaded?(chapter_path)
    path = File.join(@source.storage_path, chapter_path)
    Dir.exist?(path) && !Dir.empty?(path)
  end

  def metadata(mal_id)
    jikan_service.manga_full_by_id(mal_id)
  end

  def search(params)
    jikan_service.search(params)
  end

  private

  def jikan_service
    @jikan_service ||= Jikan.new
  end
end
