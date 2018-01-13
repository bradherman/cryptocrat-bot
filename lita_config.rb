Lita.configure do |config|
  config.robot.name = "."
  config.robot.mention_name = "."
  config.robot.alias = "."

  config.robot.locale = :en

  # config.redis
  config.redis[:url] = ENV["REDISTOGO_URL"]

  config.robot.log_level = :info

  # An array of user IDs that are considered administrators. These users
  # the ability to add and remove other users from authorization groups.
  # What is considered a user ID will change depending on which adapter you use.
  # config.robot.admins = ["1", "2"]

  ## Example: Set options for the chosen adapter.
  # config.adapter.username = "myname"
  # config.adapter.password = "secret"

  # config.redis[:url]  = ENV["REDISTOGO_URL"]
  # config.http.port    = ENV["PORT"]

  ## Example: Set configuration for any loaded handlers. See the handler's
  ## documentation for options.
  # config.handlers.some_handler.some_config_key = "value"

  config.robot.adapter = :slack
  # config.robot.admins = [ENV["ADMIN_ID"]]
  config.adapters.slack.token = ENV['SLACK_TOKEN']

  # config.adapters.slack.link_names = true
  # config.adapters.slack.parse = "full"
  # config.adapters.slack.unfurl_links = false
  # config.adapters.slack.unfurl_media = false
end
