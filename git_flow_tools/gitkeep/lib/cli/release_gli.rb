# frozen_string_literal: true

require 'logger'

# none of these are needed yet (but will be)
require_relative 'git_utils'
require_relative 'token_utils'
require_relative 'github_utils'
require_relative 'merger'
require_relative 'release_cutter'
require_relative 'dashboard_utils'
require_relative 'notification'
require_relative 'jenkins_utils'
require_relative 'slack_utils'
require_relative 'xcode_utils'

module Gitkeep
  module CLI
    help_text = "Cuts a release by creating and naming a branch, pushing to
    github, bumping the version number, creating a PR for version number bump,
    sending notification emails and updating Cornerstone's dashboard"
    desc help_text

    desc 'Cut a release branch and perform post release steps'
    arg_name '<args>...', %i[multiple]
    command :cut_release do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.desc 'The version number to be used'
      c.flag %i[v version], type: String
      c.desc 'sha to be used (Default head of develop)'
      c.flag %i[s sha], type: String
      c.desc 'The previous release branch name'
      c.flag %i[p previous_branch], type: String
      c.desc 'The next version number to be used'
      c.flag %i[n next_version], type: String
      c.desc 'Test Mode - does no external operations but logs web requests and git operations instead.'
      c.switch %i[t test_mode]

      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Cutting release for #{options[:version]}."
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        logger.info "Cutting release for #{options[:version]}."
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        release_cutter.cut_release
      end
    end
    command :notify_branch_creation do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.desc 'The new release branch name'
      c.flag %i[v version], type: String
      c.desc 'The previous release branch name'
      c.flag %i[p previous_branch], type: String
      c.desc 'Test Mode - does no external operations but logs web requests and git operations instead.'
      c.switch %i[t test_mode]
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Sending branch creation notification: #{options[:version]}"
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        notification = Notification.new(logger, git_utilities, options)
        notification.email_branch_creation(release_cutter.prs_for_release)
      end
    end
    command :open_prs do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get open PRs'
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        release_cutter.open_pull_requests
      end
    end
    command :closed_prs do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get closed PRs'
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        release_cutter.closed_pull_requests
      end
    end
    command :pr do |c|
      c.desc 'The PR number'
      c.flag %i[n pr_number], type: String
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get PR'
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        release_cutter.single_pull_request
      end
    end
    command :releases do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get Releases'
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        release_cutter.releases
      end
    end
    command :commits_for_release do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get commits for release'
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        puts release_cutter.commits_for_release
      end
    end
    command :prs_for_release do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.desc 'The previous release branch name'
      c.flag %i[p previous_branch], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get PRs for release'
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        puts release_cutter.prs_for_release
      end
    end
    command :single_commit do |c|
      c.desc 'The commit sha'
      c.flag %i[s sha], type: String
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info 'Get commit'
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        release_cutter.single_commit
      end
    end
    command :add_tag do |c|
      c.desc 'The version number to be used'
      c.flag %i[v version], type: String
      c.desc 'Test Mode - does no external operations but logs web requests and git operations instead.'
      c.switch %i[t test_mode]
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Adding tag cut-#{options[:version]}"
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        git_utilities.add_tag("cut-#{options[:version]}")
      end
    end
    command :dashboard_release do |c|
      c.desc 'release version'
      c.flag %i[v version], type: String
      c.desc 'build number'
      c.flag %i[b build_number], type: String
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        dashboard_utils = DashboardUtils.new(logger, false)
        dashboard_utils.release_release(options[:version], options[:build_number])
      end
    end
    command :enable_pr_testing do |c|
      c.desc 'test mode'
      c.switch %i[t test_mode]
      c.desc 'branch to add PR testing to'
      c.flag %i[b branch_name], type: String
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Adding pr testing to #{options[:branch_name]}"
        jenkins_utils = JenkinsUtils.new(logger, options[:test_mode])
        token_utilities = TokenUtils.new(logger)
        token = token_utilities.find('gitkeep')
        jenkins_utils.update_jenkins_whitelist_pr_test_branches(options[:branch_name], token)
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        github_utilities = GitHubUtils.new(logger, options[:location], git_utilities.origin_repo_name, options[:test_mode])
        github_utilities.setup_status_checks(options[:branch_name], token)
      end
    end

    command :xcode_version_boost do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.desc 'test mode'
      c.switch %i[t test_mode]
      c.desc 'The next version number to be used'
      c.flag %i[n next_version], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        release_cutter = ReleaseCutter.new(logger, options[:location], git_utilities, options)
        release_cutter.xcode_version_boost
      end
    end

    command :send_slack do |c|
      c.desc 'channel to send to'
      c.flag %i[c channel], type: String
      c.desc 'message to send'
      c.flag %i[m message], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Sending message: '#{options[:message]}' to channel: #{options[:channel]}"
        slack_utilities = SlackUtils.new(logger)
        slack_utilities.send_message(options[:channel], options[:message])
      end
    end

    command :compare_branch_status do |c|
      c.desc 'test mode'
      c.switch %i[t test_mode]
      c.desc 'branch to check (normally develop)'
      c.flag %i[b base_branch], type: String
      c.desc 'branch to be compare against (normally the release branch)'
      c.flag %i[o other_branch], type: String
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.action do |_global_option, options, _args|
        logger = Logger.new(STDOUT)
        logger.info "Checking #{options[:base_branch]} against #{options[:other_branch]}"
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        if git_utilities.branches_in_sync?(options[:base_branch], options[:other_branch])
          logger.info "Branch #{options[:other_branch]} is present in #{options[:base_branch]}"
        else
          logger.info "Branch #{options[:other_branch]} has not been merged with #{options[:base_branch]}"
          exit(false)
        end
      end
    end
  end
end
