# frozen_string_literal: true

require 'fileutils'
require_relative 'text_utils'
require_relative 'dashboard_utils'
require_relative 'jenkins_utils'
require_relative 'xcode_utils'

class ReleaseCutter
  def initialize(logger, path, git_utilities, options)
    @logger = logger
    @git_utilities = git_utilities
    @path = path
    token_utilities = TokenUtils.new(logger)
    @token = token_utilities.find('gitkeep')
    @github_utilities = GitHubUtils.new(logger, path, git_utilities.origin_repo_name, options[:test_mode])
    @options = options
  end

  def release_branch
    @git_utilities.release_branch_name(@options[:version])
  end

  def version_branch
    @git_utilities.feature_branch_name("#{@options[:next_version]}-version-change")
  end

  def develop_branch
    'develop'
  end

  def xcode_version_boost
    xcode_version_changer = XCodeUtils.new
    text_utilities = if @options[:test_mode]
                       TextUtilsTest.new(@logger)
                     else
                       TextUtils.new(@logger)
                     end
    if @options[:next_version].nil?
      @logger.info 'No next version passed in'
      @options[:next_version] = xcode_version_changer.increment_minor_xcode_version(text_utilities, @logger)
      @logger.info "Automatically bumping version number to #{@options[:next_version]}"
    end
    @git_utilities.new_branch(version_branch)
    return false unless xcode_version_changer.change_xcode_version(text_utilities, @logger, @options[:next_version])
    @git_utilities.add_file_to_commit(xcode_version_changer.xcode_proj_location)
    @git_utilities.commit_changes("Updating version number to #{@options[:next_version]}")
    @git_utilities.push_to_origin(version_branch)
    @github_utilities.version_change_pull_request(@options[:next_version], version_branch, develop_branch, @token)
    true
  end

  def previous_release_branch
    @git_utilities.release_branch_name((@options[:previous_branch]).to_s)
  end

  def perform_initial_git_operations
    return false unless @git_utilities.branches_in_sync?(develop_branch, previous_release_branch)
    return false unless xcode_version_boost
    return false unless verify_develop_state
    @git_utilities.add_tag("cut-#{@options[:version]}")
    @logger.info 'Cut point tagged'
    @logger.info "Release branch will be called #{release_branch}"
    @git_utilities.new_branch(release_branch)
    @git_utilities.push_to_origin(release_branch)
    true
  end

  def perform_web_operations
    jenkins_utils = JenkinsUtils.new(@logger, @options[:test_mode])
    jenkins_utils.update_jenkins_whitelist_pr_test_branches(release_branch, @token)
    jenkins_utils.update_build_branch('main_regression_multijob_branch', release_branch, @token, 'REGISTER_BRANCH')
    jenkins_utils.update_build_branch('register-beta-itc-builder-swift4', release_branch, @token, 'BRANCH_TO_BUILD')
    jenkins_utils.update_build_branch('iOS-develop-release-merge-checker', release_branch, @token, 'RELEASE_BRANCH')
    dashboard_utils = DashboardUtils.new(@logger, @options[:test_mode])
    dashboard_utils.dashboard_cut_new_release(@options[:version], release_branch)
  end

  def cut_release
    return false unless verify_parameters
    return false unless verify_develop_state
    return false unless perform_initial_git_operations
    perform_web_operations
    notification = Notification.new(@logger, @git_utilities, @options)
    notification.email_branch_creation(prs_for_release)
    @logger.info 'complete, exiting'
  end

  def verify_parameters
    if @github_utilities.valid_credentials?(@token) == false
      @logger.error 'Credentials incorrect, please verify your OAuth token is valid'
      return false
    end
    @logger.info 'Credentials authenticated'

    if defined?(@options[:version]).nil?
      @logger.error 'Incomplete parameters'
      return false
    end
    true
  end

  def verify_develop_state
    @git_utilities.obtain_latest
    @git_utilities.checkout_local_branch('develop')

    if @git_utilities.remote_branch?('develop') == false
      @logger.error 'SCRIPT_LOGGER:: Remote branch develop does not exist.'
      return false
    end
    true
  end

  def open_pull_requests
    @github_utilities.open_pull_requests(@token)
  end

  def closed_pull_requests
    @github_utilities.closed_pull_requests(@token)
  end

  def single_pull_request
    @github_utilities.single_pull_request(@token, @options[:pr_number])
  end

  def releases
    @github_utilities.releases(@token)
  end

  def single_commit
    @github_utilities.single_commit(@token, @options[:sha])
  end

  def verify_branch?
    if @git_utilities.remote_branch?(@options[:previous_branch]) == false
      @logger.warn 'Requested previous branch does not exist on remote: ' + @options[:previous_branch]
      @logger.info 'Check your branch name and try again'
      exit
    end
    true
  end

  def commits_for_release
    return nil unless verify_branch?
    @logger.info "Finding commits that are in origin/develop and not in origin/#{@options[:previous_branch]} (no merges)"
    str_result = "git --git-dir=#{@path}.git log origin/#{@options[:previous_branch]}..origin/develop --oneline --no-merges"
    str_array = str_result.split "\n"
    result = []
    str_array.each do |str_|
      result.push(str_.to_s.rpartition('/').last)
    end
    result
  end

  def commit_shas_for_release
    return nil unless verify_branch?
    @logger.info "Finding commits that are in origin/develop and not in origin/#{@options[:previous_branch]} (no merges)"
    str_result = "git --git-dir=#{@path}.gitlog origin/#{@options[:previous_branch]}..origin/develop --format=format:%h --no-merges"
    str_array = str_result.split "\n"
    result = []
    str_array.each do |str_|
      result.push(str_.to_s.rpartition('/').last)
    end
    result
  end

  def branch_cut_date
    cut_date = "git --git-dir=#{@path}.git log -1 --format=%ai cut-#{@options[:previous_branch]}"
    cut_date.split(' ').first
  end

  def prs_for_release
    @github_utilities.prs_for_release(@token, branch_cut_date)
  end
end
