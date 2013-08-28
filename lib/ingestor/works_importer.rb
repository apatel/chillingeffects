module Ingestor
  class WorksImporter

    attr_reader :field_group

    def initialize(file_path)
      @file_path = file_path
      @works = {}
    end

    def parse_works
      file_handle = File.open(@file_path)
      @field_group = 0

      file_handle.each do |line|
        line.chomp!
        extract_work_description(line)
        extract_copyrighted_urls(line)
        extract_infringing_urls(line)
      end
      @works
    end

    def self.create_instances(file_path)
      importer = self.new(file_path)
      works_instances = []
      importer.parse_works.each do |field_group_index, data|
         works_instances << Work.new(
           description: data[:description],
           infringing_urls_attributes: data[:infringing_urls].collect{|url| {url: url}},
           copyrighted_urls_attributes: data[:copyrighted_urls].collect{|url| {url: url}}
         )
      end
      works_instances
    end

    private

    def extract_work_description(line)
      if line.match(/field_group_(\d+)_work_description/)
        @field_group = $1.to_i
        @works[field_group] = {}
        (junk, description) = line.split(':', 2)
        @works[field_group][:description] = description
      end
    end

    def extract_copyrighted_urls(line)
      if line.match(/field_group_#{field_group}_copyright_work_url/)
        extract_url(line, :copyrighted_urls)
      end
    end

    def extract_infringing_urls(line)
      if line.match(/field_group_#{field_group}_infringement_url/)
        extract_url(line, :infringing_urls)
      end
    end

    def extract_url(line, type)
      (junk, url) = line.split(':', 2)
      @works[field_group][type] ||= []
      @works[field_group][type] << url
    end

  end
end
