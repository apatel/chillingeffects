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

    def import
      self.each do |csv_row|
        Dmca.create!(
          AttributeMapper.transform(csv_row)
        )
      end
    end

    def each(&block)
      init_headers
      @lines.each do |line|
        yield CSV.parse_line(line, col_sep: COL_SEP, headers: @headers)
      end
    end
  end

  private

  class AttributeMapper
    def self.transform(csv_row)
      hash = csv_row.to_hash
      {
        original_notice_id: hash['NoticeID'],
        title: hash['Subject'],
        works: Ingestor::WorksImporter.import(hash['OriginalFilePath']),
        entity_notice_roles: [
          EntityNoticeRole.new(
            name: 'sender',
            entity: Entity.new(name: hash['Sender_Principal'])
          ),
          EntityNoticeRole.new(
            name: 'recipient',
            entity: Entity.new(name: hash['Recipient_Entity'])
          ),
        ]
      }
    end
  end

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
