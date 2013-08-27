module Ingestor
  class WorksImporter
    def self.import(file_path)
      # Return an array of works.
      [ Work.new(
          infringing_urls: [ InfringingUrl.new(url: 'http://example.com/infringing_urls')],
          copyrighted_urls: [ CopyrightedUrl.new(url: 'http://example.com/copyrighted_urls')],
          description: 'A series of videos',
        )
      ]
    end
  end

  private

end
