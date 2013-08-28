require 'spec_helper'
require 'ingestor'

feature "Importing CSV" do
  scenario "notices are created" do
    ingestor = Ingestor::LegacyCsv.open(
      'spec/support/example_files/example_notice_export.csv.gz'
    )
    ingestor.import

    notice = Dmca.last
    expect(notice.title).to eq 'Music DMCA (Copyright) Complaint to Google'
    expect(notice.original_notice_id).to eq 342342

    expect(notice.works.length).to eq 2
  end
end
