# frozen_string_literal: true

require 'logger'
require 'io/console'

require_relative 'git_utils'
require_relative 'token_utils'
require_relative 'github_utils'
require_relative 'merger'

module Gitkeep
  module CLI
    help_text = "This is the setup and general operations for gitkeep

    GitKeep needs an oauth token to run. Add the oauth token to the key
    chain ->

    bin/gitkeep setup_oauth --oauth_token [INSERT_OAUTH_KEY_HERE]
    "
    desc help_text
    arg_name '<args>...', %i[multiple]
    command :setup_oauth do |c|
      c.desc 'The oauth token to be used in setup_oauth'
      c.flag %i[o oauth_token], type: String
      c.desc 'Delete the configured oauth token for the merge script'
      c.switch %i[d delete_token]
      c.desc 'Output the autocomplete list for setup'
      c.switch %i[c complete]
      c.desc 'Test mode'
      c.switch %i[t test_mode]
      c.action do |_global_options, options, _args|
        logger = Logger.new(STDOUT)
        token_utilities = TokenUtils.new(logger)
        if options[:complete]
          options.each_key do |key|
            if key.length > 2
              puts '--' << key.to_s
            else
              puts '-' << key.to_s
            end
          end
        else
          if options[:delete_token]
            token_utilities.remove('gitkeep')
          else
            unless options[:oauth_token]
              logger.error 'SCRIPT_LOGGER:: Need an oauth token to set! exit and use -o TOKEN_STRING, or input below'
              options[:oauth_token] = STDIN.noecho(&:gets).chomp
            end
            logger.info 'Saving gitkeep token'
            token_utilities.save('gitkeep', options[:oauth_token])
          end
          token_utilities.save('gitkeep', options[:oauth_token])
        end
      end
    end

    help_text = "This is the setup and general operations for gitkeep

    GitKeep needs an email address for some operations to run. Add the email to the key
    chain ->

    bin/gitkeep setup_email --email_address [INSERT_EMAIL_HERE] --email_password [INSERT_EMAIL_PASSWORD_HERE]
    "
    desc help_text
    arg_name '<args>...', %i[multiple]
    command :setup_email do |c|
      c.desc 'Delete the configured email for the merge script'
      c.switch %i[d delete_email]
      c.desc 'Output the autocomplete list for setup_email'
      c.switch %i[c complete]
      c.desc 'The email address to be used in setup'
      c.flag %i[e email_address], type: String
      c.desc 'The email address password to be used'
      c.flag %i[p password], type: String
      c.desc 'Test mode'
      c.switch %i[t test_mode]
      c.action do |_global_options, options, _args|
        logger = Logger.new(STDOUT)
        token_utilities = TokenUtils.new(logger)
        if options[:complete]
          options.each_key do |key|
            if key.length > 2
              puts '--' << key.to_s
            else
              puts '-' << key.to_s
            end
          end
        else
          if options[:delete_email]
            token_utilities.remove('gitkeep_email_address')
            token_utilities.remove('gitkeep_email_password')
          else
            unless options[:email_address]
              logger.error 'SCRIPT_LOGGER:: Need an email address to set! Exit and use -e EMAIL_STRING, or input below'
              options[:email_address] = $stdin.gets.chomp
            end

            unless options[:email_password]
              logger.error 'SCRIPT_LOGGER:: Need an email password to set! Exit and use -p EMAIL_PASSWORD or input below'
              options[:email_password] = STDIN.noecho(&:gets).chomp
            end
            logger.info 'Saving email address and password to keychain'
          end
          token_utilities.save('gitkeep_email_address', options[:email_address])
          token_utilities.save('gitkeep_email_password', options[:email_password])
        end
      end
    end
  end
end
