require 'spec_helper'
require 'ingestor/legacy_csv'

describe Ingestor::LegacyCsv do
  include IngestorHelpers

  context '.open' do
    it "raises when the file isn't there" do
      expect{
        described_class.open('null')
      }.to raise_error(Ingestor::FileNotThere)
    end

    it "opens a gzipped file" do
      File.stub(:exist?).and_return(true)
      Zlib::GzipReader.should_receive(:open).with('filename.gz')
      described_class.open('filename.gz')
    end
  end

  it "returns enumerable parsed rows" do
    ingestor = open_valid_file
    row = ingestor.first
    expect(row).to have_key('NoticeID').with_value('3168232342342')
  end

  def open_valid_file
    open_file('spec/support/example_files/example_notice_export.csv.gz')
  end

  def open_file(file)
    described_class.open(file)
  end

end
