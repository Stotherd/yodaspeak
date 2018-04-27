# frozen_string_literal: true

require 'mail'

require_relative 'token_utils'

def send_email(logger, opts = {})
  token_utilities = TokenUtils.new(logger)

  opts[:address]              ||= 'smtp.gmail.com'
  opts[:port]                 ||= '587'
  opts[:user_name]            ||= token_utilities.find('gitkeep_email_address')
  opts[:password]             ||= token_utilities.find('gitkeep_email_password')
  opts[:authentication]       ||= 'plain'
  opts[:enable_starttls_auto] ||= true
  opts[:email_to]             ||= token_utilities.find('gitkeep_email_address')
  opts[:email_from]           ||= 'cornerstone@shopkeep.com'
  opts[:email_from_alias]     ||= 'Cornerstone'
  opts[:email_subject]        ||= ''
  opts[:email_body]           ||= ''

  Mail.defaults do
    delivery_method :smtp, opts
  end

  mail = Mail.deliver do
    charset = 'UTF-8'
    to opts[:email_to]
    from opts[:email_from_alias] + '<' + opts[:email_from] + '>'
    subject opts[:email_subject]

    text_part do
      content_type 'text/html; charset=utf-8'
      body opts[:email_body]
    end
  end

  mail.deliver!
end
