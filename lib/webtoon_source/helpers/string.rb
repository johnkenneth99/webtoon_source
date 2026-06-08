# frozen_string_literal: true

class WebtoonSource
  module Helpers
    module String # rubocop:disable Style/Documentation
      def self.snake_case(string)
        string.gsub(/([A-Z]+[a-z]+)/) { |match| "_#{match.downcase}" }
      end
    end
  end
end
