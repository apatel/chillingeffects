require 'spec_helper'
require 'ingestor'

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

  it "is enumerable" do
    ingestor = described_class.open(
      'spec/support/example_files/example_notice_export.csv.gz'
    )
    expect(ingestor).to respond_to(:each)
  end

end
