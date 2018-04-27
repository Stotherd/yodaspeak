# frozen_string_literal: true

require_relative 'email'

class Notification
  def initialize(logger, git_utilities, options)
    @logger = logger
    @git_utilities = git_utilities
    @options = options
  end

  def release_branch
    @git_utilities.release_branch_name(@options[:version])
  end

  def email_branch_creation(prs_for_release)
    html_prs = []
    prs_for_release.each do |i|
      html_prs.push("<a href='https://github.com/shopkeep/ipad-register/pull/" + i.split(' ').first + "'>" + i + '</a>')
    end

    email_subject = "New branch created: #{release_branch}"
    email_body = "Branch #{release_branch} has been created and we are preparing for a release. <br /> <br />" + html_prs.join('<br />')
    if @options[:test_mode]
      @logger.info "TEST MODE EMAIL CALL:: Subject: #{email_subject}, Text: #{email_body}"
      return
    end
    send_email @logger, email_subject: email_subject, email_body: email_body
    @logger.info 'Email sent with Subject: ' + email_subject
  end
end
