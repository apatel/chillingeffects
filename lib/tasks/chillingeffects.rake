require 'rake'

namespace :chillingeffects do

  desc 'Delete elasticsearch index'
  task delete_search_index: :environment do
    Notice.index.delete
    sleep 5
  end

  desc "Import legacy chillingeffects data"
  task import_legacy_data: :environment do
    if ENV['FILE_NAME'].blank?
      puts "Please specify the file name via the FILE_NAME environment variable"
    end
  end

end
