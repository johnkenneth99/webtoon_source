# frozen_string_literal: true

require_relative "webtoon_source/version"
require_relative "webtoon_source/configuration"
require_relative "webtoon_source/asura_scans"
require "faraday"

module WebtoonSource
  class Error < StandardError; end
end
