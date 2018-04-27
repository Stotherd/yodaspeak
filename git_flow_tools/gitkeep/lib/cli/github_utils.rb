# frozen_string_literal: true

# Utilites for using the github api
require 'net/http'
require 'json'
require 'ostruct'
class GitHubUtils
  def initialize(log, path, repo_id, test_mode)
    @test_mode = test_mode
    @logger = log
    @repo_id = repo_id
  end

  def issue_id(body)
    hashed_json = JSON.parse(body)
    hashed_json['number']
  end

  def issue_url(body)
    hashed_json = JSON.parse(body)
    hashed_json['url']
  end

  def build_http_request(uri_tail, type, body, oauth_token)
    uri = URI("https://api.github.com/repos/#{@repo_id}#{uri_tail}")
    if type == 'POST'
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = body
    elsif type == 'PUT'
      req = Net::HTTP::Put.new(uri, 'Content-Type' => 'application/json')
      req.body = body
    elsif type == 'GET'
      req = Net::HTTP::Get.new(uri)
    end
    req['Authorization'] = "token #{oauth_token}"
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  end

  def both_branches_present?(url, head, base, branch_a, branch_b)
    return false unless head.include? branch_a
    return false unless base.include? branch_b
    @logger.info "SCRIPT_LOGGER:: #{url}, #{head} into #{base}"
    @logger.info 'SCRIPT_LOGGER:: This ^^^ pull request branch name includes both branches we want to merge.'
    true
  end

  def branch_present?(url, head, base, branch_a)
    return false unless base.include? branch_a
    @logger.info "SCRIPT_LOGGER:: #{url}, #{head} into #{base}"
    @logger.info 'SCRIPT_LOGGER:: This ^^^ pull request base branch is the same as the branch we want to merge into.'
    true
  end

  def does_pull_request_exist?(branch_a, branch_b, oauth_token)
    branch_exists = false
    JSON.parse(build_http_request('/pulls', 'GET', nil, oauth_token).body).each do |i|
      branch_exists = both_branches_present?(i['url'], i['head']['ref'], i['base']['ref'], branch_a, branch_b)
      next unless branch_present?(i['url'], i['head']['ref'], i['base']['ref'], branch_a)
      branch_exists = true
    end
    branch_exists
  end

  def verify_pull_request_opened?(body, title, current_branch)
    if pull_request_opened?(body)
      @logger.info "SCRIPT_LOGGER:: Created pull request:
      #{title}: #{issue_url(body)}"
    else
      @logger.error 'SCRIPT_LOGGER:: Could not create the pull request -
      response to network request was: '
      @logger.error body
      @logger.error "SCRIPT_LOGGER:: reverting back to #{current_branch}"
      system("git --git-dir=#{@path}.git checkout #{current_branch} > /dev/null 2>&1")
      @logger.error "SCRIPT_LOGGER::
      ================ The pull request was rejected by github. ================
      Please see log above for an indication of the error. The #{current_branch}
      branch has been checked out."
      exit
    end
  end

  def merger_pull_request(merge_branch, current_branch, oauth_token)
    text = "Automated pull request of #{merge_branch} into #{current_branch}"
    if @test_mode
      @logger.info "TEST MODE GITHUB OPS :: PR POST, text: #{text}"
      return
    end
    res = build_http_request('/pulls', 'POST', { title: text,
                                                 body: text,
                                                 head: merge_branch,
                                                 base: current_branch }.to_json, oauth_token)
    verify_pull_request_opened?(res.body, text, current_branch)
    add_label_to_issue(issue_id(res.body),
                       "⇝ Forward – DON'T SQUASH",
                       oauth_token)
  end

  def pull_request_opened?(body)
    body.include? 'state":"open'
  end

  def setup_status_checks(branch_name, oauth_token)
    status_checks = {   strict: false,
                        contexts: %w[Appium-Swift4 Unit\ and\ KIF\ PR\ Tests] }
    required_pr_reviews = {   dismiss_stale_reviews: true,
                              require_code_owner_reviews: false }
    json_for_protection = { required_status_checks: status_checks,
                            enforce_admins: false,
                            required_pull_request_reviews: required_pr_reviews,
                            restrictions: nil }
    if @test_mode
      @logger.info "TEST MODE GITHUB OPS :: STATUS CHECKS PUT, text: #{json_for_protection}"
      return
    end
    build_http_request("/branches/#{branch_name}/protection", 'PUT', json_for_protection.to_json, oauth_token)
  end

  def version_change_pull_request(version, version_branch, develop_branch, oauth_token)
    setup_status_checks(develop_branch, oauth_token)
    title = "Bumping version number for #{develop_branch} to #{version} "
    body_text = "Automated pull request to bump the version number for #{develop_branch} for the next release, #{version} "

    if @test_mode
      @logger.info "TEST MODE GITHUB OPS :: Release PR, title: #{title}, text: #{body_text}"
      return
    end
    res = build_http_request('/pulls', 'POST', { title: title,
                                                 body: body_text,
                                                 head: version_branch,
                                                 base: develop_branch }.to_json, oauth_token)
    verify_pull_request_opened?(res.body, title, version_branch)
  end

  def add_label_to_issue(issue_number, label, oauth_token)
    build_http_request("/issues/#{issue_number}/labels", 'POST', "[\n\"#{label}\"\n]", oauth_token)
  end

  def valid_credentials?(oauth_token)
    uri = URI("https://api.github.com/?access_token=#{oauth_token}")
    res = Net::HTTP.get_response(uri)
    res.code == '200'
  end

  def open_pull_requests(oauth_token)
    JSON.parse(build_http_request('/pulls', 'GET', nil, oauth_token).body).each do |i|
      @logger.info i['title']
    end
  end

  def closed_pull_requests(oauth_token)
    JSON.parse(build_http_request('/pulls?state=closed?per_page=1', 'GET', nil, oauth_token).body).each do |i|
      @logger.info i
    end
  end

  def single_pull_request(oauth_token, pr_number)
    result = JSON.parse(build_http_request("/pulls/#{pr_number}", 'GET', nil, oauth_token).body)
    @logger.info result
  end

  def releases(oauth_token)
    JSON.parse(build_http_request('/releases', 'GET', nil, oauth_token).body).each do |i|
      @logger.info i['tag_name']
    end
  end

  def single_commit(oauth_token, sha)
    JSON.parse(build_http_request("/commits/#{sha}", 'GET', nil, oauth_token).body)
  end

  def prs_for_release(oauth_token, cut_date)
    @logger.info "Searching GitHub for PRs that have been merged on or after #{cut_date}, with a base branch of develop"
    prs = []
    for i in 1..5 do
      JSON.parse(build_http_request("/pulls?state=closed&base=develop&per_page=100&page=#{i}", 'GET', nil, oauth_token).body).each do |d|
        next if (d['merged_at']).nil?
        if Date.parse(d['merged_at']) >= Date.parse(cut_date)
          prs.push((d['number']).to_s + ' : ' + d['title'])
        end
      end
    end
    prs
  end
end
