require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require "sinatra/reloader" if development?
require 'net/http'
require 'pp'
require 'ruby-debug'

get '/internal/:domain/:ip' do |domain, ip|
  url = URI.parse('http://' + ip + '/')
  return download_body url, domain, ip
end

get '/internal/:domain/:ip/*' do |domain, ip, q|
  url = URI.parse('http://' + ip + '/' + params['splat'].first)
  return download_body url, domain, ip
end

def download_body url, domain, ip
  request_url = request.env['rack.url_scheme'] + '://' + request.env['HTTP_HOST'] + '/' + request.env['PATH_INFO'].split('/')[1..3].join('/') + '/'
  
  req = Net::HTTP::Get.new(url.path)
  req.add_field("Host", domain)
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end
  content_type res.content_type
  
  # TODO: Make appended url relative to whatever server it was accessed on
  # TODO: Support SSL
  # TODO: Fix ajax
  # Make sure that relative urls without the slash get one appended
  res.body.gsub!(/(src=|href=)(["'])([^\/(http)][^"]+)"/, '\1\2/\3"')
  
  # Make sure that relative urls get the proxy address appended
  res.body.gsub!(/(src=|href=)(["'])\//, '\1\2' + request_url)
  
  # Make sure ajax calls are getting rerouted correctly
  res.body.gsub!(/\$\.(get|post)\((['"])([^"]*)/, '$.\1(\2' + request_url + '\3')
  
  return res.body
end