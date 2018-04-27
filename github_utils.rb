class GitHubUtils


    $repo_id = "stotherd/yodaspeak"
    def initialize(logger, git_utils)
        $logger = logger
        $git_utils = git_utils
    end

    def get_issue_id(body)
        hashed_json = JSON.parse(body)
        return hashed_json["number"]
    end
    def get_issue_url(body)
        hashed_json = JSON.parse(body)
        return hashed_json["url"]
    end

    def check_if_pull_request_exists(branch_a, branch_b, oauth_token)
        uri = URI("https://api.github.com/repos/#{$repo_id}/pulls")
        req = Net::HTTP::Get.new(uri)
        req['Authorization'] = "token #{oauth_token}"
        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) {|http|
          http.request(req)
        }
        hashed_json = JSON.parse(res.body)
        branch_exists = false
        hashed_json.each do |i|
            if(i["head"]["ref"].include? branch_a) && (i["head"]["ref"].include? branch_b)
                $logger.info "SCRIPT_LOGGER:: #{i["url"]}, #{i["head"]["ref"]} into #{i["base"]["ref"]}"
                $logger.info "SCRIPT_LOGGER:: This ^^^ pull request branch name includes both branches we want to merge."
                branch_exists = true

            end
            if(i["base"]["ref"].include? branch_a)
                $logger.info "SCRIPT_LOGGER:: #{i["url"]}, #{i["head"]["ref"]} into #{i["base"]["ref"]}"
                $logger.info "SCRIPT_LOGGER:: This ^^^ pull request base branch is the same as the branch we want to merge into."
                branch_exists = true
            end
        end
        return branch_exists
    end

    def fm_pull_request(merge_branch, current_branch, oauth_token)

        uri = URI("https://api.github.com/repos/#{$repo_id}/pulls")
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

        req['Authorization'] = "token #{oauth_token}"
        title = "Automated pull request of #{merge_branch} into #{current_branch}"
        body = "Automated pull request of #{merge_branch}, into the #{current_branch} branch"
        req.body = {title: title, body: body, head: merge_branch, base: current_branch}.to_json
        res = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') {|http| http.request(req)}

        if(res.body.include? "state\":\"open")
            issue_url = get_issue_url(res.body)
            $logger.info "SCRIPT_LOGGER:: Created pull request: #{title}: #{issue_url}"
        else
            $logger.error "SCRIPT_LOGGER:: Could not create the pull request - response to network request was: "
            $logger.error res.body
            $logger.error "SCRIPT_LOGGER:: reverting back to #{current_branch}"
            system("git checkout #{current_branch} > /dev/null 2>&1")
            $logger.error "SCRIPT_LOGGER:: checked out #{current_branch}."
            $logger.error "SCRIPT_LOGGER:: ================= The pull request was rejected by github. =================

            Please see log above for an indication of the error. The #{current_branch} branch has been checked out.
            Please check the forward-merge branch for changes. Should you wish to remove the forward branch, run:
            ./git_tool -l #{current_branch} -m #{merge_branch} -c -r"
            exit
        end
        label = "forward merge"
        number = get_issue_id(res.body)
        add_label_to_issue(number, label, oauth_token)
    end

    def add_label_to_issue(issue_number, label, oauth_token)
        uri = URI("https://api.github.com/repos/#{$repo_id}/issues/#{issue_number}/labels")
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req['Authorization'] = "token #{oauth_token}"
        req.body = "[\n\"#{label}\"\n]"
        res = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') {|http| http.request(req)}
    end

    def check_credentials_are_valid(oauth_token)

        uri = URI("https://api.github.com/?access_token=#{oauth_token}")
        res = Net::HTTP.get(uri)
        if(res.include? "current_user_url\":\"https://api.github.com/user")
            $logger.info "SCRIPT_LOGGER:: Authenticated! Carry on"
            return true
        else
            $logger.error "SCRIPT_LOGGER:: API returned #{res} to authentitcation request."
            return false
        end
    end
end
