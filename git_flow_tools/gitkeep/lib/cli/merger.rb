# frozen_string_literal: true

class Merger
  def initialize(logger, path, git_utilities, options)
    @logger = logger
    @path = path
    @git_utilities = git_utilities
    if !options[:oauth_token].nil?
      @token = options[:oauth_token]
    else
      token_utilities = TokenUtils.new(logger)
      @token = token_utilities.find('gitkeep')
    end
    @github_utilities = GitHubUtils.new(
      logger,
      path,
      git_utilities.origin_repo_name,
      options[:test_mode]
    )
    @options = options
  end

  def merge_branch
    @git_utilities.merge_branch_name(
      @options[:base_branch],
      @options[:merge_branch]
    )
  end

  def merge
    return false unless verify_parameters
    return false unless check_previous_requests
    @logger.info "SCRIPT_LOGGER:: Merging #{@options[:merge_branch]} into #{@options[:base_branch]}"
    verification_result = verify_branch_state
    exit unless verification_result[0]
    return false unless create_branch_as_required(
      verification_result[1],
      verification_result[2]
    )
    @git_utilities.safe_merge(merge_branch, @options[:merge_branch])
    return false unless perform_github_ops(perform_push)
  end

  def verify_parameters
    if @github_utilities.valid_credentials?(@token) == false
      @logger.error 'Credentials incorrect, please verify your OAuth token is valid'
      return false
    end
    @logger.info 'Credentials authenticated'

    if defined?(@options[:merge_branch]).nil? || defined?(@options[:base_branch]).nil?
      @logger.error 'Incomplete parameters'
      return false
    end
    true
  end

  def check_previous_requests
    if @github_utilities.does_pull_request_exist?(
      @options[:base_branch],
      @options[:merge_branch],
      @token
    )
      if @options[:automatic]
        @logger.warn
        'SCRIPT_LOGGER:: Possible pull request already in progress.'
      else
        unless @git_utilities.user_input_to_continue(
          "SCRIPT_LOGGER:: Possible matching pull request detected.
          If the branch name generated matches that of a pull request,
          and the changes are pushed to origin, that pull request will be
          updated.
          Check above logs.
          Do you wish to continue? (y/n)"
        )
          return false
        end
      end
    end
    true
  end

  def verify_branch_state
    @git_utilities.obtain_latest
    @git_utilities.checkout_local_branch(@options[:base_branch])
    @git_utilities.obtain_latest
    @git_utilities.push_to_origin(@options[:base_branch])

    remote_merge_branch_present = false
    local_merge_branch_present = false
    remote_forward_merge_branch_present = false

    if @git_utilities.remote_branch?(@options[:merge_branch]) == false
      @logger.error
      "SCRIPT_LOGGER:: Remote branch #{@options[:merge_branch]} does not exist."
      return [remote_merge_branch_present, local_merge_branch_present, remote_forward_merge_branch_present]
    end

    remote_merge_branch_present = true
    if @git_utilities.local_branch?(merge_branch) == true
      @logger.warn "SCRIPT_LOGGER:: Merge branch #{merge_branch} already locally exists."
      local_merge_branch_present = true
    end

    if @git_utilities.remote_branch?(merge_branch) == true
      @logger.warn "SCRIPT_LOGGER:: Merge branch #{merge_branch} already remotely exists."
      remote_forward_merge_branch_present = true
    end
    [remote_merge_branch_present, local_merge_branch_present, remote_forward_merge_branch_present]
  end

  def continue_after_diff?
    return true unless @options[:automatic]
    @git_utilities.system_command("git --git-dir=#{@path}.git --work-tree=#{@path} diff origin/#{@options[:base_branch]} #{merge_branch}", false)
    return false unless @git_utilities.user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches. Do you wish to continue with the merge? (y/n)')
    true
  end

  def resolve_git_if_either_branch_present(local_branch_present, remote_branch_present)
    if local_branch_present
      @git_utilities.checkout_local_branch(merge_branch)
      if remote_branch_present
        @git_utilities.obtain_latest
      elsif @options[:push] == true
        @git_utilities.push_to_origin(merge_branch)
      end
    elsif remote_branch_present && @git_utilities.system_command("git --git-dir=#{@path}.git --work-tree=#{@path} checkout -b #{merge_branch} origin/#{merge_branch} > /dev/null 2>&1", true) != true
      @logger.error "SCRIPT_LOGGER:: Failed to checkout #{merge_branch} from remote."
      return false
    end
    @logger.info "SCRIPT_LOGGER:: Checking branch state"
    return false unless @git_utilities.branch_up_to_date?(merge_branch, @options[:base_branch]) != true
    @logger.info "SCRIPT_LOGGER:: Updating #{merge_branch} with latest from #{@options[:base_branch]}"
    return false unless continue_after_diff?
    @logger.info "SCRIPT_LOGGER:: Updating #{merge_branch} with latest from #{@options[:base_branch]}"
    @git_utilities.safe_merge(merge_branch, @options[:base_branch])
    @git_utilities.push_to_origin(merge_branch) if @options[:push] == true
  end

  def resolve_git_if_neither_present
    @logger.info "SCRIPT_LOGGER:: Merge branch will be called #{merge_branch}"
    if @git_utilities.branch_up_to_date?(@options[:base_branch], @options[:merge_branch]) == true
      @logger.info "SCRIPT_LOGGER:: We don't need to Merge these 2 branches. Exiting..."
      return false
    end
    @logger.info "past check"
    unless @options[:automatic]
      @git_utilities.system_command("git --git-dir=#{@path}.git --work-tree=#{@path} diff #{@options[:base_branch]} #{@options[:merge_branch]}", true)
      unless @git_utilities.user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches.
        Do you wish to continue? (y/n)')
        return false
      end
    end

    if @git_utilities.system_command("git --git-dir=#{@path}.git --work-tree=#{@path} checkout -b #{@options[:base_branch]} origin/#{@options[:base_branch]} > /dev/null 2>&1", true) != true
      @logger.warn "SCRIPT_LOGGER:: Failed to checkout #{@options[:base_branch]} from remote, checking if locally available."
      if @git_utilities.system_command("git --git-dir=#{@path}.git --work-tree=#{@path} checkout #{@options[:base_branch]} > /dev/null 2>&1", true) != true
        @logger.error 'SCRIPT_LOGGER:: Failed to checkout branch locally, unable to continue.'
        return false
      end
    end
    @logger.info "SCRIPT_LOGGER:: Successfully checked out the #{@options[:base_branch]} branch"
    if @git_utilities.system_command("git --git-dir=#{@path}.git --work-tree=#{@path} checkout -b #{merge_branch}", true) != true
      @logger.error 'SCRIPT_LOGGER:: Failed to create new branch.'
      return false
    else
      @logger.info 'SCRIPT_LOGGER:: Branch created.'
    end
  end

  def create_branch_as_required(local_branch_present, remote_branch_present)
    if local_branch_present || remote_branch_present
      resolve_git_if_either_branch_present(local_branch_present, remote_branch_present)
    else
      resolve_git_if_neither_present
    end
  end

  def perform_push
    pushed = false
    if @options[:push]
      @logger.info "SCRIPT_LOGGER:: Pushing #{merge_branch} to origin."
      @git_utilities.push_to_origin(merge_branch)
      pushed = true
    elsif !@options[:automatic]
      if @git_utilities.user_input_to_continue('SCRIPT_LOGGER:: Do you want to push to origin? (Required for pull request)(y/n)')
        @logger.info "SCRIPT_LOGGER:: Pushing #{merge_branch} to origin."
        @git_utilities.push_to_origin(merge_branch)
        pushed = true
      else
        exit
      end
    end
    pushed
  end

  def force_merge_check
    return unless @options[:force_merge]
    @git_utilities.final_clean_merge(@options[:base_branch], merge_branch)
  end

  def github_automatic_ops
    return if @options[:automatic]
    @git_utilities.system_command("git --git-dir=#{@path}.git --work-tree=#{@path} diff #{@options[:base_branch]} origin/#{merge_branch}", false)
    return true unless @git_utilities.user_input_to_continue('SCRIPT_LOGGER:: Based on the above diff, do you want to create a pull request? (y/n)')
    @github_utilities.merger_pull_request(merge_branch, @options[:base_branch], @token)
    false
  end

  def perform_github_ops(pushed)
    if @options[:generate_pull_request]
      if pushed
        @logger.info 'SCRIPT_LOGGER:: Creating pull request.'
        @github_utilities.merger_pull_request(merge_branch, @options[:base_branch], @token)
      else
        @logger.info 'SCRIPT_LOGGER:: Unable to create pull request, as the changes have not been pushed.'
      end
      return false
    end
    force_merge_check
    return false unless github_automatic_ops
    return false unless @git_utilities.user_input_to_continue('SCRIPT_LOGGER:: Do you want to finish the merge without a pull request? (y/n)')
    @git_utilities.final_clean_merge(@options[:base_branch], merge_branch)
  end
end
