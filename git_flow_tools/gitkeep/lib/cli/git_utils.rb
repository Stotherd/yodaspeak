# frozen_string_literal: true

require 'git'

# Git utilities using the ruby gem ruby-git
class GitUtils
  def initialize(log, path, test_mode)
    @logger = log
    @path = path
    @git ||= Git.open(path.chomp)
    @test_mode = test_mode
  end

  def system_command(command, writable)
    if @test_mode && writable
      @logger.info "TEST_MODE:: #{command}"
      return true
    end
    @logger.info "COMMAND:: #{command}"
    system(command)
  end

  def merger_clean(branch_you_were_on,
                   branch_to_be_deleted,
                   clean_remote)
    @logger.info "SCRIPT_LOGGER:: Checking out #{branch_you_were_on}"
    system_command("git --git-dir=#{@path}.git --work-tree=#{@path} merge --abort > /dev/null 2>&1", true)
    system_command("git --git-dir=#{@path}.git --work-tree=#{@path} checkout #{branch_you_were_on}  > /dev/null 2>&1", true)
    system_command("git --git-dir=#{@path}.git --work-tree=#{@path} branch -D #{branch_to_be_deleted}   > /dev/null 2>&1", true)
    if clean_remote == true
      system_command("git --git-dir=#{@path}.git --work-tree=#{@path} push origin --delete #{branch_to_be_deleted} > /dev/null 2>&1", true)
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
    if @test_mode
      @logger.info 'TEST_MODE GIT CALL:: git.fetch'
      @logger.info "TEST_MODE GIT CALL:: @git.pull(#{@git.remote}, #{@git.current_branch})"
    else
      @git.fetch
      @git.pull(@git.remote, @git.current_branch)
    end
  end

  def checkout_local_branch(branch_name)
    if @test_mode
      @logger.info "TEST_MODE GIT CALL:: git.checkout(#{branch_name})"
    else
      @git.checkout(branch_name)
    end
  end

  def new_branch(branch_name)
    @logger.info "branch creating: #{branch_name}"
    return if @test_mode
    @git.branch(branch_name)
    @git.branch(branch_name).checkout
  end

  def add_file_to_commit(filename)
    if @test_mode
      @logger.info "TEST_MODE GIT CALL:: @git.add(#{filename}))"
    else
      @git.add(filename)
    end
  end

  def commit_changes(message)
    if @test_mode
      @logger.info "TEST_MODE GIT CALL::  @git.commit(#{message}))"
    else
      @git.commit(message)
    end
  end

  def push_to_origin(branch_name)
    if @test_mode
      @logger.info "TEST_MODE GIT CALL::  @git.push(#{@git.remote}, #{branch_name}))"
    else
      @git.push(@git.remote, branch_name)
    end
  end

  def merge_branch_name(base_branch, merge_branch)
    "auto/merge-#{merge_branch}-to-#{base_branch}"
  end

  def release_branch_name(version)
    "release/#{version}"
  end

  def feature_branch_name(version)
    "feature/#{version}"
  end

  def branch_up_to_date?(branch_you_are_on, branch_to_be_checked_against)
    sha_of_to_be_merged = `git --git-dir=#{@path}.git --work-tree=#{@path} rev-parse origin/#{branch_to_be_checked_against}`


    tree_of_branch_you_are_on = `git --git-dir=#{@path}.git --work-tree=#{@path} log --pretty=short #{branch_you_are_on}`


    if tree_of_branch_you_are_on.include? sha_of_to_be_merged
      @logger.info "SCRIPT_LOGGER:: Head of #{branch_to_be_checked_against} is present in #{branch_you_are_on}."
      return true
    end
    number_of_commits_scanned = tree_of_branch_you_are_on.scan(/commit/).count
    @logger.info "SCRIPT_LOGGER:: Scanned #{number_of_commits_scanned} commits
    in #{branch_you_are_on} and none match the head of #{branch_to_be_checked_against}."
    false
  end

  def branches_in_sync?(branch_a, branch_b)
    if remote_branch?(branch_a) == false
      @logger.error "SCRIPT_LOGGER:: Remote branch #{branch_b} does not exist."
      return false
    end
    checkout_local_branch(branch_a)
    obtain_latest
    if remote_branch?(branch_b) == false
      @logger.error "SCRIPT_LOGGER:: Remote branch #{branch_b} does not exist."
      return false
    end
    checkout_local_branch(branch_b)
    obtain_latest
    checkout_local_branch(branch_a)
    branch_up_to_date?(branch_a, branch_b)
  end

  def safe_merge(base_branch, to_be_merged_in_branch)
    unless system_command("git --git-dir=#{@path}.git --work-tree=#{@path} merge origin/#{to_be_merged_in_branch} --no-edit", true)
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
    system_command("git --git-dir=#{@path}.git --work-tree=#{@path} merge origin/#{to_be_merged_in_branch} --no-edit", true)
  end

  def user_input_to_continue(warning)
    complete = false
    until complete
      @logger.info warning
      decision = $stdin.gets
      return false if (decision.chomp.casecmp 'n').zero?
      return true if (decision.chomp.casecmp 'y').zero?
    end
  end

  def final_clean_merge(base_branch, head_branch)
    if system_command("git --git-dir=#{@path}.git --work-tree=#{@path} checkout #{base_branch} > /dev/null 2>&1", true) != true
      logger.error 'SCRIPT_LOGGER:: Failed to checkout branch locally, unable
      to continue'
      exit
    end
    safe_merge(base_branch, head_branch)
    push_to_origin(base_branch)
    merger_clean(base_branch, head_branch, true)
  end

  def origin_repo_name
    str = @git.config('remote.origin.url')
    str.to_s.rpartition(':').last.rpartition('.').first
  end

  def log
    @git.log
  end

  def add_tag(tag_name)
    if @test_mode
      @logger.info "TEST_MODE GIT CALL:: git.add_tag(#{tag_name})"
    else
      @git.add_tag(tag_name)
      @git.push('origin', "refs/tags/#{tag_name}")
    end
  end
end
