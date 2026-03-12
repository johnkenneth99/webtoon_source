# frozen_string_literal: true

module WebtoonSource
  BASE_STORAGE_PATH = "webtoon_source"

  class Configuration
    attr_accessor :storage_path

    def initialize
      @storage_path = File.join(Dir.home, BASE_STORAGE_PATH)
    end
  end
end
