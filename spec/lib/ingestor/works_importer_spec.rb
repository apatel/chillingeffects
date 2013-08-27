require 'spec_helper'
require 'ingestor'

describe Ingestor::WorksImporter do
  it "gets works" do
    importer = importer_with_valid_file
    expect(importer.works.length).to eq 2
  end

  it "can get work descriptions" do
    importer = importer_with_valid_file

    descriptions = importer.works.collect do |field_group, work_data|
      work_data[:description]
    end

    expect(descriptions).to match_array(
      [
        'Video and Image series produced by Copyright Owner LLC.',
        'Video and Image series produced by Copyright Owner LLC.',
      ]
    )
  end

  it "can get copyrighted urls" do
    importer = importer_with_valid_file

    works = importer.works
    expect(works[0][:copyrighted_urls]).to match_array(
      %w|http://example.com/original_work_url
      http://example.com/original_work_url_again|
    )
    expect(works[1][:copyrighted_urls]).to match_array(
      %w|http://example.com/original_work_url
      http://example.com/original_work_url_dos|
    )
  end

  it "can get infringing urls" do
    importer = importer_with_valid_file

    works = importer.works
    expect(works[0][:infringing_urls]).to match_array(
      %w|http://infringing.example.com/url_0
         http://infringing.example.com/url_1|
    )
    expect(works[1][:infringing_urls]).to match_array(
      %w|http://infringing.example.com/url_second_0
         http://infringing.example.com/url_second_1|
    )
  end

  private

  def importer_with_valid_file
    described_class.new('spec/support/example_files/original_notice_source.txt')
  end
end
