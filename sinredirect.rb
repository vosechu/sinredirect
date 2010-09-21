require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'curb'
get '/internal/:domain/:ip' do |domain, ip|
  Curl::Easy.perform(ip) do |curl| 
    curl.headers["Host"] = domain
  end
end