# TODO: Support SSL
# TODO: Make some sort of authentication scheme so it's not a wildly open proxy

require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require "sinatra/reloader" if development?
require 'net/http'
require 'pp'
require 'ruby-debug'

get '/internal/:domain/:ip' do |domain, ip|
  url = URI.parse('http://' + ip + '/')
  return singet url, domain, ip
end

get '/internal/:domain/:ip/*' do |domain, ip, q|
  url = URI.parse('http://' + ip + '/' + q)
  return singet url, domain, ip
end

post '/internal/:domain/:ip/*' do |domain, ip, q|
  url = URI.parse('http://' + ip + '/' + q)
  return sinpost url, domain, ip, request.env['rack.request.form_vars']
end


def singet url, domain, ip, limit=10
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0
  
  req = Net::HTTP::Get.new(url.path)
  req.add_field("Host", domain)
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end
  content_type res.content_type
  
  case res
  when Net::HTTPSuccess     then transform_response res.body
  when Net::HTTPRedirection then singet(URI.parse('http://' + ip + '/' + res['location']), domain, ip, limit - 1)
  end
end

def sinpost url, domain, ip, form_vars
  req = Net::HTTP::Post.new(url.path)
  req.add_field("Host", domain)
  
  # Mangle the form variables from query string to a hash for Net::HTTP
  form_vars = form_vars.split('&').inject({}) {|memo,v| memo.merge({v.split('=').first => v.split('=').last}) }
  req.set_form_data(form_vars)
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end
  content_type res.content_type
  
  case res
  when Net::HTTPSuccess     then transform_response res.body
  when Net::HTTPRedirection then singet(URI.parse('http://' + ip + '/' + res['location']), domain, ip, 9)
  end
end

def transform_response body
  request_url = request.env['rack.url_scheme'] + '://' + request.env['HTTP_HOST'] + '/' + request.env['PATH_INFO'].split('/')[1..3].join('/') + '/'
  
  transformations = [
    # Make sure that relative urls without the slash get one appended
    [/(action=|src=|href=)(["'])([^\/(http)][^"]+)"/, '\1\2/\3"'],
    # Make sure that relative urls get the proxy address appended
    [/(action=|src=|href=)(["'])\//, '\1\2' + request_url],
    # Make sure ajax calls are getting rerouted correctly
    [/\$\.(get|post)\((['"])([^"]*)/, '$.\1(\2' + request_url + '\3']
  ]
  
  transformations.each do |pair|
    body.gsub! pair.first, pair.last
  end
  
  return body
end