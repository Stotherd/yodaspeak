
require 'keyring'

class KeyringUtils

    def initialize(logger)
        $logger = logger
    end
    $keyring = Keyring.new

    def set_token(app_name, token)
        $keyring.delete_password(app_name, ENV['USER'])
        $keyring.set_password(app_name, ENV['USER'], token)
        $logger.info "SCRIPT_LOGGER:: OAuth Key added to keychain"
    end

    def remove_token(app_name)
        $keyring.delete_password(app_name, ENV['USER'])
        $logger.info "SCRIPT_LOGGER:: Key removed from keychain"
    end

    def get_token(app_name)
        return $keyring.get_password(app_name, ENV['USER'])
    end

end
