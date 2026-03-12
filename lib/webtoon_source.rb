# frozen_string_literal: true

require_relative "webtoon_source/version"
require_relative "webtoon_source/configuration"
require_relative "webtoon_source/asura_scans"
require "faraday"

class WebtoonSource
  class Error < StandardError; end
  attr_accessor :storage_path

  def initialize(platform = "asura_scans")
    @platform = platform

    yield(self) if block_given?
  end
end
