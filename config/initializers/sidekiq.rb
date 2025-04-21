require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.on(:startup) do
    schedule_file = Rails.root.join("config/sidekiq_scheduler.yml")

    if File.exist?(schedule_file)
      Sidekiq.schedule = YAML.load_file(schedule_file)
      Sidekiq::Scheduler.reload_schedule!
    end
  end
end

