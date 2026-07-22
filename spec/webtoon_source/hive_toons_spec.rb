# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

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
      expect(panels.base_url).to eq("https://storage.hivetoon.com")
      expect(panels.panel_list.size).to eq(50)
    end

    it "orders each panel by its reader index and captures its file extension" do
      first_panel_path = "/public/upload/series/reborn-rich-the-youngest-son-of-a-conglomerate/" \
                          "chapter_1_Kj2Vb9dhgVhwT2/1_1_1732148207213.webp"

      first_panel = source.panels.panel_list.first

      expect(first_panel).to eq(
        WebtoonSource::Base::Panel.new(path: first_panel_path, order: "0", file_extension: "webp")
      )
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
      expect(chapters.map(&:number)).to eq(%w[213 212])
    end

    it "maps only the allowed chapter fields, snake_cased, and stashes the rest in metadata" do
      chapter = source.chapters.first

      expect(chapter.to_h.keys).to contain_exactly(
        :is_locked, :id, :number, :slug, :title, :series_slug, :path, :metadata
      )
      expect(chapter.metadata.keys).to contain_exactly(:created_at)
    end

    it "builds the chapter path from the series slug and chapter slug" do
      chapter = source.chapters.first
      expect(chapter.path).to eq("/series/#{series_slug}/chapter-213")
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

  describe "#download" do
    let(:series_slug) { "reborn-rich-the-youngest-son-of-a-conglomerate" }
    let(:chapter_number) { "1" }
    let(:fixture_path) { File.expand_path("../fixtures/hive_toons/chapter.html", __dir__) }
    let(:html_content) { File.read(fixture_path) }
    let(:storage_path) { Dir.mktmpdir }
    let(:cdn_base_url) { "https://storage.hivetoon.com" }
    let(:cdn_stubs) { Faraday::Adapter::Test::Stubs.new }

    before do
      cdn_conn = Faraday.new(cdn_base_url) do |builder|
        builder.adapter :test, cdn_stubs
      end

      allow(Faraday).to receive(:new).and_call_original
      allow(Faraday).to receive(:new).with(cdn_base_url).and_return(cdn_conn)

      cdn_stubs.get(/.*/) { [200, {}, "panel-bytes"] }

      source.storage(storage_path)
    end

    after { FileUtils.remove_entry(storage_path) }

    it "raises when chapter_number, series_slug, or directory_name is missing" do
      expect { source.download }.to raise_error(ArgumentError)
    end

    context "when the series and chapter are already set" do
      before do
        source.series(series_slug).chapter(chapter_number).directory(series_slug.gsub("-", "_"))
        stubs.get("/series/#{series_slug}/chapter-#{chapter_number}") do
          [200, { "Content-Type" => "text/html" }, html_content]
        end
      end

      it "writes every panel into a directory named after the series and chapter" do
        source.download

        chapter_directory = File.join(storage_path, series_slug.gsub("-", "_"), chapter_number)
        expect(Dir.children(chapter_directory).size).to eq(50)
      end

      it "names each panel file by its padded order and file extension" do
        source.download

        chapter_directory = File.join(storage_path, series_slug.gsub("-", "_"), chapter_number)
        expect(Dir.children(chapter_directory).min).to eq("00.webp")
      end
    end

    context "with a specific chapter_url" do
      let(:chapter_url) { "https://hivetoons.org/series/reborn-rich/chapter-1/" }

      before do
        stubs.get("/series/reborn-rich/chapter-1") do
          [200, { "Content-Type" => "text/html" }, html_content]
        end
      end

      it "derives series_slug, chapter_number, and directory_name from the URL" do
        source.download(chapter_url)

        chapter_directory = File.join(storage_path, "reborn_rich", "1")
        expect(Dir.exist?(chapter_directory)).to be true
        expect(source.series_slug).to eq("reborn-rich")
      end
    end
  end
end
