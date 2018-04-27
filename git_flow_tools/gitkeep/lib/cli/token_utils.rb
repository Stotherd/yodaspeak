# frozen_string_literal: true

# Class for manipulating tokens on the keychain
class TokenUtils
  def initialize(log)
    @logger = log
  end

  def save(app_name, token)
    remove(app_name)
    if system("security add-generic-password -a #{ENV['USER']} -s #{app_name} -w #{token}")
      @logger.info 'SCRIPT_LOGGER:: Key added to keychain'
    else
      @logger.error 'SCRIPT_LOGGER:: unable to add key to keychain'
    end
  end

  def remove(app_name)
    return unless system("security delete-generic-password -a #{ENV['USER']} -s #{app_name}")
    @logger.info 'SCRIPT_LOGGER:: Key removed from keychain'
  end

  def find(app_name)
    `security find-generic-password -a #{ENV['USER']} -s #{app_name} -w`.chomp
  end
end
