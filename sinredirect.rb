require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'net/http'
require 'pp'

get '/internal/:domain/:ip' do |domain, ip|
  url = URI.parse('http://' + ip + '/')
  req = Net::HTTP::Get.new(url.path)
  req.add_field("Host", domain)
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end

  res.body.gsub(/"\//, "\"http://localhost:4567/internal/#{domain}/#{ip}/")
end

get '/internal/:domain/:ip/*' do |domain, ip, q|
  url = URI.parse('http://' + ip + '/' + params['splat'].first)
  req = Net::HTTP::Get.new(url.path)
  p '****' + url.path
  req.add_field("Host", domain)
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end

  res.body.gsub(/"\//, "\"http://localhost:4567/internal/#{domain}/#{ip}/")
end