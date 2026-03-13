# frozen_string_literal: true

# Source of metadata.
class WebtoonSource::Jikan
  VERSION = "v4"

  def initialize
    @conn = Faraday.new("https://api.jikan.moe") do |config|
      config.request :json
      config.response :json
      config.response :raise_error
    end
  end

  def manga_full_by_id(mal_id)
    response = @conn.get("#{VERSION}/manga/#{mal_id}/full")
    response.body["data"]
  end

  def search(params)
    response = @conn.get("#{VERSION}/manga", params)
    response.body
  end
end
