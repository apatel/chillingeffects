require 'zlib'
require 'ingestor'

module Ingestor
  class LegacyCsv
    include Enumerable

    COL_SEP = "\t"

    def self.open(file_name)
      if File.exist?(file_name)
        new(FileOpener.open(file_name))
      else
        raise Ingestor::FileNotThere
      end
    end

    def initialize(lines)
      @lines = lines
    end

    def init_headers
      @headers ||= CSV.parse_line(@lines.first, col_sep: COL_SEP)
    end

    def each(&block)
      init_headers
      @lines.each do |line|
        yield CSV.parse_line(line, col_sep: COL_SEP, headers: @headers)
      end
    end
  end

  private

  class FileOpener
    def self.open(file_name)
      if file_name.match(/\.gz\z/)
        Zlib::GzipReader.open(file_name)
      else
        File.open(file_name)
      end
    end
  end
end
