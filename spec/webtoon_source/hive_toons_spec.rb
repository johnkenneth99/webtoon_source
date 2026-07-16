# frozen_string_literal: true

require "spec_helper"

RSpec.describe WebtoonSource::HiveToons do
  let(:base_url) { "https://hivetoons.org/" }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new(base_url) do |builder|
      builder.adapter :test, stubs
    end
  end

  subject(:source) do
    described_class.new(base_url) do |s|
      s.instance_variable_set(:@conn, conn)
    end
  end

  describe "abstract method overrides" do
    it "implements #download" do
      expect(source.method(:download).owner).to eq(described_class)
    end

    it "implements #panels" do
      expect(source.method(:panels).owner).to eq(described_class)
    end

    it "implements #chapters" do
      expect(source.method(:chapters).owner).to eq(described_class)
    end
  end

  describe "#panels" do
    let(:series_slug) { "reborn-rich-the-youngest-son-of-a-conglomerate" }
    let(:chapter_number) { "1" }
    let(:fixture_path) { File.expand_path("../fixtures/hive_toons/chapter.html", __dir__) }
    let(:html_content) { File.read(fixture_path) }

    before do
      source.series(series_slug).chapter(chapter_number)
      stubs.get("/series/#{series_slug}/chapter-#{chapter_number}") do
        [200, { "Content-Type" => "text/html" }, html_content]
      end
    end

    it "returns the CDN base_url and the full panel_list" do
      panels = source.panels
      expect(panels[:base_url]).to eq("https://storage.hivetoon.com")
      expect(panels[:panel_list].size).to eq(50)
    end

    it "orders each panel by its reader index and captures its file extension" do
      first_panel_path = "/public/upload/series/reborn-rich-the-youngest-son-of-a-conglomerate/" \
                          "chapter_1_Kj2Vb9dhgVhwT2/1_1_1732148207213.webp"

      first_panel = source.panels[:panel_list].first

      expect(first_panel).to eq(path: first_panel_path, order: "0", file_extension: "webp")
    end

    context "with a specific chapter_url" do
      let(:chapter_url) { "https://hivetoons.org/series/reborn-rich/chapter-1/" }

      before do
        stubs.get(chapter_url) do
          [200, { "Content-Type" => "text/html" }, html_content]
        end
      end

      it "derives series_slug from the given URL" do
        source.panels(chapter_url)
        expect(source.series_slug).to eq("reborn-rich")
      end
    end
  end

  describe "#chapters" do
    let(:series_slug) { "reborn-rich-the-youngest-son-of-a-conglomerate" }
    let(:fixture_path) { File.expand_path("../fixtures/hive_toons/series.html", __dir__) }
    let(:html_content) { File.read(fixture_path) }

    before do
      source.series(series_slug)
      stubs.get("/series/#{series_slug}") do
        [200, { "Content-Type" => "text/html" }, html_content]
      end
    end

    it "returns chapters sorted by number, descending" do
      chapters = source.chapters
      expect(chapters.map { |chapter| chapter[:number] }).to eq(%w[213 212])
    end

    it "maps only the allowed chapter fields, snake_cased" do
      chapter = source.chapters.first
      expect(chapter.keys).to contain_exactly(:is_locked, :id, :number, :slug, :title, :series_slug, :path)
    end

    it "builds the chapter path from the series slug and chapter slug" do
      chapter = source.chapters.first
      expect(chapter[:path]).to eq("/series/#{series_slug}/chapter-213")
    end

    context "with a specific series_url" do
      let(:series_url) { "https://hivetoons.org/series/reborn-rich/" }

      before do
        stubs.get(series_url) do
          [200, { "Content-Type" => "text/html" }, html_content]
        end
      end

      it "derives series_slug from the given URL" do
        source.chapters(series_url)
        expect(source.series_slug).to eq("reborn-rich")
      end
    end
  end
end
