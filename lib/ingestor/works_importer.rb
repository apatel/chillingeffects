module Ingestor
  class WorksImporter

    attr_reader :field_group

    def initialize(file_path)
      @file_path = file_path
    end

    def works
      file_handle = File.open(@file_path)
      works = {}
      @field_group = 0

      file_handle.each_line do |line|
        line.chomp!
        extract_work_description(line, works)
        extract_copyrighted_urls(line, works)
        extract_infringing_urls(line, works)
      end

      works
    end

    def self.import(file_path)
      importer = self.new(file_path)
      works_instances = []
      importer.works.each do |field_group_index, data|
        # p field_group_index
        # p data
         works_instances << Work.new(
           description: data[:description],
           infringing_urls_attributes: data[:infringing_urls].collect{|url| {url: url}},
           copyrighted_urls_attributes: data[:copyrighted_urls].collect{|url| {url: url}}
         )
      end
      works_instances
    end

    private

    def extract_work_description(line, works)
      if line.match(/field_group_(\d+)_work_description/)
        @field_group = $1.to_i
        works[field_group] = {}
        (junk, description) = line.split(':', 2)
        works[field_group][:description] = description
      end
    end

    def extract_copyrighted_urls(line, works)
      if line.match(/field_group_#{field_group}_copyright_work_url/)
        (field_name, copyright_work_url) = line.split(':', 2)
        works[field_group][:copyrighted_urls] ||= []
        works[field_group][:copyrighted_urls] << copyright_work_url
      end
    end

    def extract_infringing_urls(line, works)
      if line.match(/field_group_#{field_group}_infringement_url/)
        (field_name, infringement_url) = line.split(':', 2)
        works[field_group][:infringing_urls] ||= []
        works[field_group][:infringing_urls] << infringement_url
      end
    end
  end
end
