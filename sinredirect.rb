require 'rubygems'
require 'bundler/setup'

require 'sinatra'
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
  req = Net::HTTP::Get.new(url.path)
  req.add_field("Host", domain)
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end
  content_type res.content_type
  
  # return res.body if res.content_type =~ /image/
  return res.body.gsub(/src="([^\/(http)][^"]+)"/, 'src="/\1"').gsub(/"\//, "\"http://localhost:9393/internal/#{domain}/#{ip}/")
end