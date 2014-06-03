class AddConfidentialToNotices < ActiveRecord::Migration
  def change
    add_column(:notices, :confidential, :boolean, default: false)
  end
end
