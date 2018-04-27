require 'git'

# Git utilities using the ruby gem ruby-git
class GitUtils
  def initialize(log)
    @logger = log
    path = `git rev-parse --show-toplevel`
    @git ||= Git.open(path.chomp)
  end

  def forward_merge_clean(branch_you_were_on,
                          branch_to_be_deleted,
                          clean_remote)
    @logger.info "SCRIPT_LOGGER:: Checking out #{branch_you_were_on}"
    system('git merge --abort > /dev/null 2>&1')
    system("git checkout #{branch_you_were_on}  > /dev/null 2>&1")
    system("git branch -D #{branch_to_be_deleted}   > /dev/null 2>&1")
    if clean_remote == true
      system("git push origin --delete #{branch_to_be_deleted} > /dev/null 2>&1")
    end
    @logger.info "SCRIPT_LOGGER:: Any merge in progress was aborted, and the
    #{branch_to_be_deleted} branch deleted."
  end

  def list_remote_branches
    str_array = @git.branches.remote
    result = []
    str_array.each do |str_|
      result.push(str_.to_s.rpartition('/').last)
    end
    result
  end

  def list_local_branches
    @git.branches.local
  end

  def remote_branch?(branch_name)
    @git.is_remote_branch?(branch_name)
  end

  def local_branch?(branch_name)
    @git.is_local_branch?(branch_name)
  end

  def obtain_latest
    @git.fetch
    @git.pull
  end

  def checkout_local_branch(branch_name)
    @git.checkout(branch_name)
  end

  def forward_branch_name(base_branch, merge_branch)
    "forward-merge-#{merge_branch}-to-#{base_branch}"
  end

  def branch_up_to_date?(branch_you_are_on, branch_to_be_checked_against)
    sha_of_to_be_merged = `git rev-parse origin/#{branch_to_be_checked_against}`
    tree_of_branch_you_are_on = `git log --pretty=short #{branch_you_are_on}`

    if tree_of_branch_you_are_on.include? sha_of_to_be_merged
      @logger.error "SCRIPT_LOGGER:: Head of #{branch_to_be_checked_against}
      appears to be present in #{branch_you_are_on}."
      return true
    end

    number_of_commits_scanned = tree_of_branch_you_are_on.scan(/commit/).count
    @logger.info "SCRIPT_LOGGER:: Scanned #{number_of_commits_scanned} commits
    in #{branch_you_are_on} and none match the head of
    #{branch_to_be_checked_against} - continuing"
    false
  end

  def push_to_origin(branch_name)
    @git.push(@git.remote, branch_name)
  end

  def safe_merge(base_branch, to_be_merged_in_branch)
    unless system("git merge origin/#{to_be_merged_in_branch} --no-edit")
      @logger.info "SCRIPT_LOGGER:: unable to merge - CTRL-C to exit or press
      enter to continue after all conflicts resolved"
      until merge_complete?(to_be_merged_in_branch)
        $stdin.gets
        @logger.error "SCRIPT_LOGGER:: There are still unresolved conflicts,
        or the repo isn't clean and the merge would break a change, or another
        issue with git preventing continuing."
      end
    end
    @logger.info "SCRIPT_LOGGER:: Merged into #{base_branch}"
  end

  def merge_complete?(to_be_merged_in_branch)
    system("git merge origin/#{to_be_merged_in_branch} --no-edit")
  end

  def get_user_input_to_continue(warning)
    complete = false
    until complete
      @logger.info warning
      decision = $stdin.gets
      return false if (decision.chomp.casecmp 'n').zero?
      return true if (decision.chomp.casecmp 'y').zero?
    end
  end

  def final_clean_merge(base_branch, head_branch)
    if system("git checkout #{base_branch} > /dev/null 2>&1") != true
      logger.error 'SCRIPT_LOGGER:: Failed to checkout branch locally, unable
      to continue'
      exit
    end
    safe_merge(base_branch, head_branch)
    push_to_origin(base_branch)
    forward_merge_clean(base_branch, head_branch, true)
  end

  def origin_repo_name
    str = @git.config('remote.origin.url')
    str.to_s.rpartition(':').last.rpartition('.').first
  end
end
