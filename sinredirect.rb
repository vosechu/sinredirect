# TODO: Support SSL
# TODO: Make some sort of authentication scheme so it's not a wildly open proxy

require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require "sinatra/reloader" if development?
require 'net/http'
require 'pp'
require 'ruby-debug'

enable :sessions

get '/internal/:ip/:domain' do |ip, domain|
  url = URI.parse('http://' + ip + '/')
  return singet url, ip, domain
end

get '/internal/:ip/:domain/*' do |ip, domain, q|
  url = URI.parse('http://' + ip + '/' + q)
  return singet url, ip, domain
end

post '/internal/:ip/:domain/*' do |ip, domain, q|
  url = URI.parse('http://' + ip + '/' + q)
  return sinpost url, ip, domain, request.env['rack.request.form_vars']
end


def singet url, ip, domain, limit=10
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0

  req = Net::HTTP::Get.new(url.path)
  req.add_field("Host", domain)
  req.add_field('cookie', session[:sin]) if session[:sin]
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end
  content_type res.content_type
  
  session[:sin] = res.response['set-cookie'] if res.response['set-cookie']

  case res
  when Net::HTTPSuccess     then transform_response res.body
  when Net::HTTPRedirection then singet(URI.parse('http://' + ip + res['location'].gsub(request.env['rack.url_scheme'] + '://' + domain, '')), ip, domain, limit - 1)
  else transform_response res.body
  end
end

def sinpost url, ip, domain, form_vars
  req = Net::HTTP::Post.new(url.path)
  req.add_field("Host", domain)
  req.add_field('cookie', session[:sin]) if session[:sin]

  # Mangle the form variables from query string to a hash for Net::HTTP
  form_vars = form_vars.split('&').inject({}) {|memo,v| memo.merge({v.split('=').first => v.split('=').last}) }
  req.set_form_data(form_vars)
  debugger
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end
  content_type res.content_type
  session[:sin] = res.response['set-cookie']

  case res
  when Net::HTTPSuccess     then transform_response res.body
  when Net::HTTPRedirection then singet(URI.parse('http://' + ip + res['location'].gsub(request.env['rack.url_scheme'] + '://' + domain, '')), ip, domain, 9)
  else transform_response res.body
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
