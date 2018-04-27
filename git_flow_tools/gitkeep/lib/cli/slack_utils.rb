# frozen_string_literal: true

require 'slack-ruby-client'

# Slack utilities using the ruby gem slack-ruby-client
class SlackUtils
  def initialize(log)
    @logger = log
  end

  def configure
    Slack.configure do |config|
      config.token = ENV['SK_SLACK_API_TOKEN']
      raise 'Missing ENV[SK_SLACK_API_TOKEN]!' unless config.token
    end
  end

  def send_message(channel, message)
    configure
    @logger.info "SCRIPT_LOGGER:: Sending message #{message} to channel #{channel}"
    client = Slack::Web::Client.new
    client.auth_test
    client.chat_postMessage(channel: "##{channel}", text: message.to_s, as_user: true)
  end
end
