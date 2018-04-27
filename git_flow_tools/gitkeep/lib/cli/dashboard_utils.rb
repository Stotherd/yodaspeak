# frozen_string_literal: true

# Utilites for using the github api
require 'net/http'
require 'json'
require 'ostruct'
require 'date'

class DashboardUtils
  def initialize(log, test_mode)
    @test_mode = test_mode
    @logger = log
  end

  def dashboard_cut_new_release(version, branch_name)
    return false if release_exists?(version)
    create_release(version, branch_name)
  end

  def change_release_state_to_beta(version)
    return false unless release_exists?(version)
    change_release_state(version, 'beta')
  end

  def release_release(version, build_number)
    return false unless release_exists?(version)
    change_release_state(version, 'store')
    body = { kind: 'store',
             build: "#{version}.#{build_number}",
             released_at: current_date('/') }.to_json
    build_http_request("/releases/#{version}/builds", 'POST', body)
  end

  def build_http_request(uri_tail, type, body)
    uri = URI("http://releases.office.production.posrip.com#{uri_tail}")
    if type == 'POST'
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = body
    elsif type == 'PUT'
      req = Net::HTTP::Put.new(uri, 'Content-Type' => 'application/json')
      req.body = body
    elsif type == 'GET'
      req = Net::HTTP::Get.new(uri)
    end

    if @test_mode
      @logger.info "TEST_MODE DASHBOARD HTTP CALL:: uri: #{uri}, body: #{body}"
    else
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: false) do |http|
        http.request(req)
      end
    end
  end

  def release_exists?(version)
    uri = URI('http://releases.office.production.posrip.com/releases')
    res = Net::HTTP.get_response(uri)
    res.body.include? "version\": \"#{version}"
  end

  def current_date(separator)
    date = Time.new
    "#{date.year}#{separator}#{date.month}#{separator}#{date.day}"
  end

  def create_release(version_name, branch_name)
    body = { version: version_name,
             code_complete_date: current_date('-'),
             branch_name: branch_name,
             state: 'alpha' }.to_json
    build_http_request('/releases', 'POST', body)
  end

  def change_release_state(version, state)
    body = { state: state }.to_json
    build_http_request("/releases/#{version}", 'PUT', body)
  end
end
