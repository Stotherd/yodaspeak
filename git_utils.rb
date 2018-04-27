require 'git'

class GitUtils

    $g = Git.open(Dir.getwd)
    def initialize(logger)
        $logger = logger
    end



    def fmclean(branch_you_were_on, branch_to_be_deleted, clean_remote)
        $logger.info "SCRIPT_LOGGER:: Checking out #{branch_you_were_on}"
        system("git merge --abort > /dev/null 2>&1")
        system("git checkout #{branch_you_were_on}  > /dev/null 2>&1")
        system("git branch -D #{branch_to_be_deleted}   > /dev/null 2>&1")
        if(clean_remote == true)
            system("git push origin --delete #{branch_to_be_deleted}  > /dev/null 2>&1")
        end
        $logger.info "SCRIPT_LOGGER:: Any merge in progress was aborted, and the #{branch_to_be_deleted} branch deleted."
    end

    def does_branch_exist_remotely(branch_name)
        if $g.is_remote_branch?(branch_name)
            return true
        end
        return false
    end


    def does_branch_exist_locally(branch_name)
        if $g.is_local_branch?(branch_name)
            return true
        end
        return false
    end

    def get_latest
        $g.fetch
        $g.pull
    end

    def checkout_local_branch(branch_name)
        $g.checkout(branch_name)
    end

    def is_branch_up_to_date(branch_you_are_on, branch_to_be_checked_against)
        sha_of_to_be_merged = %x(git rev-parse origin/#{branch_to_be_checked_against})
        tree_of_branch_you_are_on = %x(git log --pretty=short #{branch_you_are_on})

        if(tree_of_branch_you_are_on.include? sha_of_to_be_merged)
            $logger.error "SCRIPT_LOGGER:: Head of #{branch_to_be_checked_against} appears to be present in #{branch_you_are_on}."
            return 0
        end

        number_of_commits_scanned = tree_of_branch_you_are_on.scan(/commit/).count
        $logger.info "SCRIPT_LOGGER:: Scanned #{number_of_commits_scanned} commits in #{branch_you_are_on} and none match the head of #{branch_to_be_checked_against} - continuing"
        diff_of_branches = system("git diff #{branch_you_are_on} origin/#{branch_to_be_checked_against}")
        if !diff_of_branches
            $logger.error "SCRIPT_LOGGER:: Unable to diff the 2 branches, exiting"
            exit
        end


    end

    def push_to_origin(branch_name)
        $g.push($g.remote, branch_name)
    end

    def safe_merge(base_branch, to_be_merged_in_branch)
        if true != system("git merge origin/#{to_be_merged_in_branch}")
            resolved = false
            $logger.info "SCRIPT_LOGGER:: unable to merge - CTRL-C to exit or press
            enter to continue after all conflicts resolved"

            while !resolved do
                gets
                resolved = system("git merge origin/#{to_be_merged_in_branch}")
                if resolved == false
                    $logger.error "SCRIPT_LOGGER:: There are still unresolved conflicts, or the repo isn't clean and the merge would break a change, or another issue with git preventing continuing."
                end
            end
        else
            $logger.info "SCRIPT_LOGGER:: Merged into #{base_branch}"
        end

    end

    def get_user_input_to_continue(warning)
        complete = false
        while !complete do
            $logger.info warning
            decision = gets.chomp

            if (decision.casecmp "n") == 0
                complete = true
                return false
            elsif (decision.casecmp "y") == 0
                complete = true
                return true
            end
        end

    end

    def final_clean_merge(base_branch, head_branch)
        if true != system("git checkout #{base_branch} > /dev/null 2>&1")
            $logger.error "SCRIPT_LOGGER:: Failed to checkout branch locally, unable to continue"
            exit
        end
        self.safe_merge(base_branch, head_branch)
        self.push_to_origin(base_branch)
        self.fmclean(base_branch, head_branch, true)

    end
end
