# frozen_string_literal: true

class WebtoonSource
  module Helpers
    module Transformers # rubocop:disable Style/Documentation
      def self.normalize_astro_island_props(obj) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        if obj.is_a?(Array) && obj.length == 2 && [0, 1].include?(obj[0])
          normalize_astro_island_props(obj[1])
        elsif obj.is_a?(Array)
          obj.map { |item| normalize_astro_island_props(item) }
        elsif obj.is_a?(Hash)
          obj.transform_values { |v| normalize_astro_island_props(v) }
        else
          obj
        end
      end
    end
  end
end
