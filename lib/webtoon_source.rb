# frozen_string_literal: true

require_relative "webtoon_source/version"
require_relative "webtoon_source/asura_scans"
require "faraday"

class WebtoonSource
  class Error < StandardError; end

  DEFAULT_STORAGE_PATH = File.join(Dir.home, "webtoon_source")

  attr_accessor :storage_path

  def initialize(platform = "asura_scans")
    @platform = platform
    @storage_path = DEFAULT_STORAGE_PATH

    yield(self) if block_given?
  end

  # Checks if a specific chapter for a webtoon has been downloaded.
  def downloaded?(name, chapter)
    path = File.join(@storage_path, name, chapter.to_s)
    Dir.exist?(path) && !Dir.empty?(path)
  end
end
