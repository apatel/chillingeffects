require 'rake'
require 'ingestor'
require 'blog_importer'
require 'question_importer'
require 'collapses_topics'
require 'csv'

namespace :chillingeffects do
  desc 'Delete elasticsearch index'
  task delete_search_index: :environment do
    Notice.index.delete
    sleep 5
  end

  desc "Import chillingeffects data from Mysql"
  task import_notices_via_mysql: :environment do
    name = ENV['IMPORT_NAME']
    base_directory = ENV['BASE_DIRECTORY']
    where_fragment = ENV['WHERE']

    unless name && base_directory && where_fragment
      puts "You need to give an IMPORT_NAME, BASE_DIRECTORY and WHERE fragment"
      puts "See IMPORTING.md for additional details about environment variables necessary to import via mysql"
      exit
    end

    record_source = Ingestor::Legacy::RecordSource::Mysql.new(
      where_fragment, name, base_directory
    )
    ingestor = Ingestor::Legacy.new(record_source)
    ingestor.import
  end

  desc "Import latest legacy chillingeffects data from Mysql"
  task import_new_notices_via_mysql: :environment do
    # Configure the record_source
    latest_original_notice_id = Notice.maximum(:original_notice_id).to_i
    name = "latest-from-#{latest_original_notice_id}"
    base_directory = ENV['BASE_DIRECTORY']

    record_source = Ingestor::Legacy::RecordSource::Mysql.new(
      "tNotice.NoticeID > #{latest_original_notice_id}",
      name, base_directory
    )
    ingestor = Ingestor::Legacy.new(record_source)
    ingestor.import
  end

  desc "Import notice error legacy chillingeffects data from Mysql"
  task import_error_notices_via_mysql: :environment do
    # Configure the record_source
    error_original_notice_ids = NoticeImportError.pluck(:original_notice_id).join(", ")
    name = "error_notices"
    base_directory = ENV['BASE_DIRECTORY']

    record_source = Ingestor::Legacy::RecordSource::Mysql.new(
      "tNotice.NoticeID IN (#{error_original_notice_ids})",
      name, base_directory
    )
    ingestor = Ingestor::Legacy.new(record_source)
    ingestor.import
  end
  
  desc "Import failed API submissions from Mysql"
  task import_failed_api_notices_via_mysql: :environment do
    # Configure the record_source
    failed_ids_file = Rails.root.to_s + '/tmp/failed_ids.csv'
    fail_import = true
    failed_original_notice_ids = Array.new
    CSV.foreach(failed_ids_file, :headers => false) do |row|
      failed_original_notice_ids << row
    end
    failed_original_notice_ids = failed_original_notice_ids.join(", ")
    
    name = "failed_api_submissions"
    base_directory = ENV['BASE_DIRECTORY']

    record_source = Ingestor::Legacy::RecordSource::Mysql.new(
      "tNotice.NoticeID IN (#{failed_original_notice_ids})", 
      name, base_directory
    )
    ingestor = Ingestor::Legacy.new(record_source)
    ingestor.import(fail_import)
  end

  desc "Import blog entries"
  task import_blog_entries: :environment do
    with_file_name do |file_name|
      importer = BlogImporter.new(file_name)
      importer.import
    end
  end

  desc "Import questions"
  task import_questions: :environment do
    with_file_name do |file_name|
      importer = QuestionImporter.new(file_name)
      importer.import
    end
  end

  desc "Post-migration cleanup"
  task post_import_cleanup: :environment do
    from = 'DMCA Notices'
    to = 'DMCA Safe Harbor'
    collapser = CollapsesTopics.new(from, to)
    collapser.collapse
  end

  desc "Incrementally index changed model instances"
  task index_changed_model_instances: :environment do
    ReindexRun.index_changed_model_instances
  end

  desc "Recreate elasticsearch index memory efficiently"
  task recreate_elasticsearch_index: :environment do
  begin
      batch_size = (ENV['BATCH_SIZE'] || 100).to_i
      [Notice, Entity].each do |klass|
        klass.index.delete
        klass.create_elasticsearch_index
        count = 0
        klass.find_in_batches(conditions: '1 = 1', batch_size: batch_size) do |instances|
          GC.start
          instances.each do |instance|
            instance.update_index
            count += 1
            print '.'
          end
          puts "#{count} #{klass} instances indexed at #{Time.now.to_i}"
        end
      end
      ReindexRun.sweep_search_result_caches
  rescue => e
    $stderr.puts "Reindexing did not succeed because: #{e.inspect}"
    end
  end

  desc "Assign titles to untitled notices"
  task title_untitled_notices: :environment do

    # Similar to SubmitNotice model
    def generic_title(notice)
      if notice.recipient_name.present?
        "#{notice.class.label} notice to #{notice.recipient_name}"
      else
        "#{notice.class.label} notice"
      end
    end


  begin
    untitled_notices = Notice.where(title: 'Untitled')
    p = ProgressBar.create(
      title: "Renaming",
      total: untitled_notices.count,
      format: "%t: %B %P%% %E %c/%C %R/s"
    )

    untitled_notices.each do |notice|
      new_title = generic_title(notice)
      #puts %Q|Changing title of Notice #{notice.id} to "#{new_title}"|
      notice.update_attribute(:title, new_title)
      p.increment
    end
  rescue => e
    $stderr.puts "Titling did not succeed because: #{e.inspect}"
    end
  end

  desc "Index non-indexed models"
  task index_non_indexed: :environment do
  begin
    require 'tire/http/clients/curb'
    Tire.configure { client Tire::HTTP::Client::Curb }
    p = ProgressBar.create(
      title: "Objects",
      total: (Notice.count + Entity.count),
      format: "%t: %B %P%% %E %c/%C %R/s"
    )
    [Notice, Entity].each do |klass|
      ids = klass.pluck(:id)
      ids.each do |id|
        unless ReindexRun.is_indexed?(klass, id)
          puts "Indexing #{klass}, #{id}"
          klass.find(id).update_index
        end
        p.increment
      end
    end
  rescue => e
    $stderr.puts "Reindexing did not succeed because: #{e.inspect}"
    end
  end

  desc "Publish notices whose publication delay has expired"
  task publish_embargoed: :environment do
    Notice.where(published: false).each do |notice|
      notice.set_published!
    end
  end

  def with_file_name
    if file_name = ENV['FILE_NAME']
      yield file_name
    else
      puts "Please specify the file name via the FILE_NAME environment variable"
    end
  end
  
  desc "Assign blank action_taken to Google notices"
  task blank_action_taken: :environment do

  begin
    google_notices = Array.new
    Notice.all.collect{|n| n.recipient.name.include?("Google") && (!n.action_taken.blank? || !n.action_taken.nil?) ? google_notices << n : ''}
    p = ProgressBar.create(
      title: "Reassigning",
      total: google_notices.count,
      format: "%t: %B %P%% %E %c/%C %R/s"
    )

    google_notices.each do |notice|
      puts %Q|Reassigning action taken of Notice #{notice.id} to blank|
      notice.update_attribute(:action_taken, '')
      p.increment
    end
  rescue => e
    $stderr.puts "Reassigning did not succeed because: #{e.inspect}"
    end
  end

end
