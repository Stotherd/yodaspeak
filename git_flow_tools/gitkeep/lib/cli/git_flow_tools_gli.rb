# frozen_string_literal: true

require 'logger'
require 'io/console'

require_relative 'git_utils'
require_relative 'token_utils'
require_relative 'github_utils'
require_relative 'merger'

module Gitkeep
  module CLI
    help_text = "Performs a formal merge and pull request on
    Shopkeep's ipad-register repo. Run inside the repo.

    Requires gems ruby-git and gli.

    Running full command:

    Either:

    Execute your merge, following prompts ->
    bin/gitkeep merger -b [branch_you_are_on] -m [branch_to_be_merged_in]

    Or

    For a promptless execution ->
    bin/gitkeep merger -b [branch_you_are_on]
                                            -m [branch_to_be_merged_in] -p -g -a
    (-p push to master, -g generate pull request, -a automatic)

    Conflicts

    Conflicts with the merge will cause the script to pause. Fix the conflicts
    and then press enter on the script to continue.

    Clean

    reverse the attempt to merge. This will delete the created
    branch, abort the merge and checkout the branch thats the first
    parameter. Adding -r will delete the remotely created branch, and by doing
    so github will close the Pull Request if one was created.
    Some fatal logging may not be fatal. The clean function is a
    brute force method that you might want to check has fully cleaned up
    resources after.

    bin/gitkeep clean -b [branch_you_are_on] -m [branch_to_be_merged_in]

    How this script normally works:

    Builds the merge branch name
    Verify authentication
    fetch/pull to verify branch is up to date, and network is good
        git fetch
        check result of fetch
        git pull
        check result of pull
    check that to_be_merged_in_branch exists remotely
    if the merge branch already exists, remotely or locally, or both,
        check it out,
        update it if neccesary (fetch/pull/merge)
    otherwise
        go back to the original branch
        create the new merge branch
        perform merge
    push to origin (prompt or -p)
    create pull request (prompt or -g)
    "
    desc help_text
    arg_name '<args>...', %i[multiple]
    command :merger do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.desc 'Pass a base_branch'
      c.flag %i[b base_branch], type: String
      c.desc 'Pass a merge branch'
      c.flag %i[m merge_branch], type: String
      c.desc 'Push the generated branch to origin'
      c.switch %i[p push]
      c.desc 'Generate a pull request'
      c.switch %i[g generate_pull_request]
      c.desc 'Run through script with no user input where possible'
      c.switch %i[a automatic]
      c.desc 'Push up without a pull request'
      c.switch %i[f force_merge]
      c.desc 'Output the autocomplete list for a merge'
      c.switch %i[c complete]
      c.desc 'Output local branch list'
      c.switch %i[output_local]
      c.desc 'Output remote branch list'
      c.switch %i[output_remote]
      c.desc 'Override the stored, or provide a different oauth_token'
      c.flag %i[o oauth_token], type: String
      c.desc 'Test mode - this should perform no destructive/creative operations
      but will output the text of the operations to log'
      c.switch %i[t test_mode]
      c.action do |_global_options, options, _args|
        logger = Logger.new(STDOUT)
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        
        if options[:complete]
          options.each_key do |key|
            if key.length > 2
              puts '--' << key.to_s
            else
              puts '-' << key.to_s
            end
          end
        elsif options[:output_local]
          puts git_utilities.list_local_branches
        elsif options[:output_remote]
          puts git_utilities.list_remote_branches
        else
          merger = Merger.new(logger, options[:location], git_utilities, options)
          merger.merge
          logger.info 'Exiting...'
        end
      end
    end
    desc 'Clean up a previous aborted  merge request'
    arg_name '<args>...', %i[multiple]
    command :clean do |c|
      c.desc 'Location to run from'
      c.flag %i[l location], type: String
      c.desc 'Pass a base_branch'
      c.flag %i[b base_branch], type: String
      c.desc 'Pass a merge branch'
      c.flag %i[m merge_branch], type: String
      c.desc 'Clean up remote branch too'
      c.switch %i[p push_delete_to_origin]
      c.desc 'Output the autocomplete list for clean'
      c.switch %i[c complete]
      c.desc 'Output local branch list'
      c.switch %i[output_local]
      c.desc 'Output remote branch list'
      c.switch %i[output_remote]
      c.desc 'Test mode - this should perform no destructive/creative operations
      but will output the text of the operations to log'
      c.switch %i[t test_mode]
      c.action do |_global_options, options, _args|
        logger = Logger.new(STDOUT)
        git_utilities = GitUtils.new(logger, options[:location], options[:test_mode])
        if options[:complete]
          options.each_key do |key|
            if key.length > 2
              puts '--' << key.to_s
            else
              puts '-' << key.to_s
            end
          end
        elsif options[:output_local]
          puts git_utilities.list_local_branches
        elsif options[:output_remote]
          puts git_utilities.list_remote_branches
        else
          merge_branch = git_utilities.merge_branch_name(
            options[:base_branch],
            options[:merge_branch]
          )
          git_utilities.merger_clean(options[:base_branch],
                                     merge_branch,
                                     options[:push_delete_to_origin])
        end
      end
    end
  end
end
