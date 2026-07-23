# WebtoonSource

A gem to source your webtoons from webtoon platforms. Metadata integration via Jikan (MyAnimeList) is a work in progress.

## Supported Sources

- **Asura Scans** (`WebtoonSource::AsuraScans`) — https://asurascans.com
- **Vortex Scans** (`WebtoonSource::VortexScans`) — https://vortexscans.org
- **Hive Toons** (`WebtoonSource::HiveToons`) — https://hivetoons.org
- **Kayn Scan** (`WebtoonSource::KaynScan`) — https://kaynscan.org
- **Ken Comics** (`WebtoonSource::KenComics`) — https://kencomics.com

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add webtoon_source
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install webtoon_source
```

## Usage

### Basic Initialization

You can use the main `WebtoonSource` orchestrator to interact with different platforms:

```ruby
require 'webtoon_source'

# Initialize with a specific platform (defaults to :asura_scans)
source = WebtoonSource.new(:asura_scans)

# You can also configure the storage path
source.storage_path = "/path/to/my/webtoons"
```

Alternatively, you can use the source classes directly:

```ruby
asura = WebtoonSource::AsuraScans.new
vortex = WebtoonSource::VortexScans.new
hive = WebtoonSource::HiveToons.new
kayn = WebtoonSource::KaynScan.new
ken = WebtoonSource::KenComics.new
```

### Downloading Chapters

There are two ways to download a chapter:

#### 1. Using a fluent interface to set parameters
```ruby
asura.series("reincarnation-of-the-fist-king")
     .chapter(51)
     .directory("reincarnation_of_the_fist_king")
     .download
```

#### 2. Using a direct chapter URL
```ruby
asura.download("https://asurascans.com/comics/reincarnation-of-the-fist-king/chapter/51")
```

### Listing Panels

There are two ways to retrieve the list of panels for a chapter:

#### 1. Using a pre-set series slug and chapter number
```ruby
asura.series("reincarnation-of-the-fist-king").chapter(51).panels
```

#### 2. Using a direct chapter URL
```ruby
asura.panels("https://asurascans.com/comics/reincarnation-of-the-fist-king/chapter/51")
```

### Listing Chapters

There are two ways to retrieve the list of chapters for a series:

#### 1. Using a pre-set series slug
```ruby
asura.series("reincarnation-of-the-fist-king").chapters
```

#### 2. Using a direct URL
```ruby
asura.chapters("https://asurascans.com/comics/reincarnation-of-the-fist-king")
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).