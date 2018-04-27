# frozen_string_literal: true

require 'net/http'
require 'nokogiri'

# Jenkins related utilities
class JenkinsUtils
  def initialize(logger, test_mode)
    @logger = logger
    @test_mode = test_mode
  end

  def update_build_branch(jenkins_job, branch, oauth_token, parameter_name)
    @logger.info "SCRIPT_LOGGER :: getting current jenkins #{jenkins_job} config"
    config_xml = build_http_request(jenkins_job, 'config.xml', 'GET', nil, oauth_token).body
    return unless config_xml.include? 'StringParameterDefinition'
    @logger.info "SCRIPT_LOGGER :: Updating to include #{branch} as build target"
    new_config_xml = change_branch_in_config_file(config_xml, branch, parameter_name)
    @logger.info 'SCRIPT_LOGGER :: Pushing to jenkins'
    return if @test_mode
    build_http_request(jenkins_job, 'config.xml', 'POST', new_config_xml, oauth_token)
  end

  def change_branch_in_config_file(config_xml, branch_name, parameter_name)
    doc = Nokogiri::XML(config_xml)
    doc.xpath('//hudson.model.StringParameterDefinition').each do |parameter_element|
      if parameter_element.xpath('name').text.include? parameter_name
        file = parameter_element.at_css 'defaultValue'
        file.content = branch_name
      end
    end
    doc.to_xml
  end

  def add_whitelist_in_config_file(config_xml, branch)
    doc = Nokogiri::XML(config_xml)
    properties = doc.at_css 'triggers'
    parameters = properties.at_css 'whiteListTargetBranches'
    new_container_node = Nokogiri::XML::Node.new 'org.jenkinsci.plugins.ghprb.GhprbBranch', doc
    new_branch_node = Nokogiri::XML::Node.new 'branch', doc
    new_branch_node.content = branch
    new_container_node.add_child(new_branch_node)
    parameters.add_child(new_container_node)
    doc.to_xml
  end

  def update_jenkins_whitelist_branch(branch, oauth_token, jenkins_job)
    @logger.info "SCRIPT_LOGGER :: getting current jenkins #{jenkins_job} config"
    config_xml = build_http_request(jenkins_job, 'config.xml', 'GET', nil, oauth_token).body
    return unless config_xml.include? 'whiteListTargetBranches'
    @logger.info "SCRIPT_LOGGER :: Updating to include #{branch} as whitelisted target branch"
    new_config_xml = add_whitelist_in_config_file(config_xml, branch)
    @logger.info 'SCRIPT_LOGGER :: Pushing to jenkins'
    return if @test_mode
    build_http_request(jenkins_job, 'config.xml', 'POST', new_config_xml, oauth_token)
  end

  def update_jenkins_whitelist_pr_test_branches(branch, oauth_token)
    update_jenkins_whitelist_branch(branch, oauth_token, 'register-kif-pr-tester-swift4')
    update_jenkins_whitelist_branch(branch, oauth_token, 'register-appium-pr-tester-swift4')
  end

  def build_http_request(jenkins_job, uri_tail, type, body, oauth_token)
    uri = URI("https://jenkins-ios.posrip.com/job/#{jenkins_job}/#{uri_tail}")
    if type == 'POST'
      req = Net::HTTP::Post.new(uri)
      req.body = body
    elsif type == 'GET'
      req = Net::HTTP::Get.new(uri)
    end
    req.basic_auth nil, oauth_token
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  end
end
