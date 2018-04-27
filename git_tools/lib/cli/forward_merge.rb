class ForwardMerge
  def initialize(logger, git_utilities, options)
    @logger = logger
    @git_utilities = git_utilities
    token_utilities = TokenUtils.new(logger)
    @token = token_utilities.find('merge_script')
    @github_utilities = GitHubUtils.new(logger, git_utilities.origin_repo_name)
    @options = options
   end

  def forward_branch
    @git_utilities.forward_branch_name(@options[:base_branch], @options[:merge_branch])
  end

  def merge
    return false unless verify_parameters
    return false unless check_previous_requests
    @logger.info "SCRIPT_LOGGER:: Merging #{@options[:merge_branch]} into #{@options[:base_branch]}"
    verification_result = verify_branch_state
    exit unless verification_result[0]
    return false unless create_branch_as_required(verification_result[1], verification_result[2])
    @git_utilities.safe_merge(forward_branch, @options[:merge_branch])
    return false unless perform_github_ops(perform_push)
  end

  def verify_parameters
    if @github_utilities.valid_credentials?(@token) == false
      logger.error 'Credentials incorrect, please verify your OAuth token is valid'
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
    if @github_utilities.does_pull_request_exist?(@options[:base_branch], @options[:merge_branch], @token)
      if @options[:automatic]
        @logger.warn 'SCRIPT_LOGGER:: Possible pull request already in progress.'
      else
        unless @git_utilities.get_user_input_to_continue("SCRIPT_LOGGER:: Possible matching pull request detected.
    If the branch name generated matches that of a pull request, and the changes are pushed to origin, that pull request will be updated.
    Check above logs.
    Do you wish to continue? (y/n)")
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
    local_forward_branch_present = false
    remote_forward_branch_present = false

    if @git_utilities.remote_branch?(@options[:merge_branch]) == false
      @logger.error "SCRIPT_LOGGER:: Remote branch #{@options[:merge_branch]} does not exist."
      return [remote_merge_branch_present, local_forward_branch_present, remote_forward_branch_present]
    end

    remote_merge_branch_present = true
    if @git_utilities.local_branch?(forward_branch) == true
      @logger.warn "SCRIPT_LOGGER:: Forward merge branch #{forward_branch} already locally exists."
      local_forward_branch_present = true
    end

    if @git_utilities.remote_branch?(forward_branch) == true
      @logger.warn "SCRIPT_LOGGER:: Forward merge branch #{forward_branch} already remotely exists."
      remote_forward_branch_present = true
    end
    [remote_merge_branch_present, local_forward_branch_present, remote_forward_branch_present]
  end

  def create_branch_as_required(local_present, remote_present)
    if local_present || remote_present
      if local_present
        @git_utilities.checkout_local_branch(forward_branch)
        if remote_present
          @git_utilities.obtain_latest
        elsif @options[:push] == true
          @git_utilities.push_to_origin(forward_branch)
        end
      elsif remote_present && system("git checkout -b #{forward_branch} origin/#{forward_branch} > /dev/null 2>&1") != true
        @logger.error "SCRIPT_LOGGER:: Failed to checkout #{forward_branch} from remote"
        return false
      end
      if @git_utilities.branch_up_to_date?(forward_branch, @options[:base_branch]) != true
        unless @options[:automatic]
          system("git diff origin/#{@options[:base_branch]} #{forward_branch}")
          unless @git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches. Do you wish to continue with the merge? (y/n)')
            return false
          end
        end
        @logger.info "SCRIPT_LOGGER:: Updating #{forward_branch} with latest from #{@options[:base_branch]}"
        @git_utilitie.safe_merge(forward_branch, @options[:base_branch])
        @git_utilities.push_to_origin(forward_branch) if @options[:push] == true
      end
    else
      @logger.info "SCRIPT_LOGGER:: Forward merge branch will be called #{forward_branch}"
      if @git_utilities.branch_up_to_date?(@options[:base_branch], @options[:merge_branch]) == true
        @logger.info "SCRIPT_LOGGER:: We don't need to forward merge these 2 branches. Exiting..."
        return false
      end

      unless @options[:automatic]
        system("git diff #{@options[:base_branch]} #{@options[:merge_branch]}")
        unless @git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: The above diff contains the differences between the 2 branches. Do you wish to continue? (y/n)')
          return false
        end
      end

      if system("git checkout -b #{@options[:base_branch]} origin/#{@options[:base_branch]} > /dev/null 2>&1") != true
        @logger.warn "SCRIPT_LOGGER:: Failed to checkout #{@options[:base_branch]} from remote, checking if locally available"
        if system("git checkout #{@options[:base_branch]} > /dev/null 2>&1") != true
          @logger.error 'SCRIPT_LOGGER:: Failed to checkout branch locally, unable to continue'
          return false
        end
      end
      @logger.info "SCRIPT_LOGGER:: Successfully checked out the #{@options[:base_branch]} branch"
      if system("git checkout -b #{forward_branch}") != true
        @logger.error 'SCRIPT_LOGGER:: Failed to create new branch.'
        return false
      else
        @logger.info 'SCRIPT_LOGGER:: Branch created'
      end
    end
    true
  end

  def perform_push
    pushed = false
    if @options[:push]
      @logger.info "SCRIPT_LOGGER:: Pushing #{forward_branch} to origin"
      @git_utilities.push_to_origin(forward_branch)
      pushed = true
    elsif !@options[:automatic]
      if @git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Do you want to push to master? (Required for pull request)(y/n)')
        @logger.info "SCRIPT_LOGGER:: Pushing #{forward_branch} to origin"
        @git_utilities.push_to_origin(forward_branch)
        pushed = true
      else
        exit
      end
    end
    pushed
  end

  def perform_github_ops(pushed)
    if @options[:generate_pull_request]
      if pushed
        @logger.info 'SCRIPT_LOGGER:: Creating pull request'
        @github_utilities.forward_merge_pull_request(forward_branch, @options[:base_branch], @token)
      else
        @logger.info 'SCRIPT_LOGGER:: Unable to create pull request, as the changes have not been pushed.'
      end
      return false
    end

    if @options[:force_merge]
      @git_utilities.final_clean_merge(@options[:base_branch], forward_branch)
    end

    unless @options[:automatic]
      system("git diff origin/#{forward_branch} #{@options[:base_branch]}")
      if @git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Based on the above diff, do you want to create a pull request? (y/n)')
        @github_utilities.forward_merge_pull_request(forward_branch, @options[:base_branch], @token)
        return false
      end
      if @git_utilities.get_user_input_to_continue('SCRIPT_LOGGER:: Do you want to finish the merge without a pull request? (y/n)')
        @git_utilities.final_clean_merge(@options[:base_branch], forward_branch)
      end
    end
  end
end
