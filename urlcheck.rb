#!/usr/bin/env ruby
#
#title           :urlcheck.rb
#description     :check a list of urls
#author          :eric@many9s.com
#version         :0.1
#usage           :ruby urlcheck.rb
#notes           :requires curl
#==============================================================================
require 'optparse'
require 'yaml'
require 'uri'
require 'net/smtp'
if Gem::Specification::find_all_by_name('curb').any?
  require 'curb'
else
  puts "ERROR: Curb gem not found\n\n"
  exit
end

options = {}
optparser = OptionParser.new do |opts|
  opts.banner = "Usage: urlcheck.rb [options]"
  opts.on("-f", "--config_file FILE", "Path to YAML config file") do |option|
      options[:config_file] = option
  end
end

begin
  optparser.parse!
rescue OptionParser::MissingArgument => e
  puts e
  exit
end

# urlcheck.list in same dir by default
begin
  CONFIGFILE  = YAML.load_file(options[:config_file] || 'urlcheck.yml')
rescue Errno::ENOENT => e
  puts "Could not find config file"
  exit
end

@config     = CONFIGFILE["config"].each_with_object({}) { |(k,v),memo| memo[k.to_sym] = v }
urls        = CONFIGFILE["urls"]
@dirty      = false

def process_urls(urllist)
  responses = {}

  urllist.each do |line|

    url   = line["url"]
    code  = line["code"]

    begin
      ret = Curl.get(URI.encode(url))
      if code.to_i == ret.response_code 
        responses[url] = "OK"
      else
        # Code was different than expected
        responses[url] = "CODE_MISMATCH"
        @dirty = true
      end
    rescue Curl::Err::SSLPeerCertificateError => e
      if code.to_i == 000
        # 000 is Curl's "server's up, but not responding on SSL"
        responses[url] = "NOSSL EXPECTED"
      else
        # SSL was expected at this URL
        responses[url] = "SSLFAIL"
        @dirty = true
      end
    rescue Curl::Err::HostResolutionError => e
      puts "ERROR: #{url}: #{e}"
    rescue Curl::Err::ConnectionFailedError => e
      puts "ERROR: Could not connect: #{e}"
    end
  end
  responses
end

def compose_email(responses)
  if responses.any?

    padding = responses.keys.max_by(&:length).length + 3
    msg   = "Subject: urlcheck #{(@dirty ? "FAILURES" : "OK")}\n\n"

    responses.each do |url,status|
      # add a space after url so Thunderbird doesn't 
      # linkify the dot leader
      formatted_url = "#{url} ".ljust(padding,'.')
      msg += "#{formatted_url}#{status}\n"
    end

  else
    msg = "Subject: urlcheck returned nothing"
  end
  msg
end

def mail_message(message)
  mailfrom    = @config[:mail_from]    || ENV['USER']
  mailto      = @config[:mail_to]      || mailfrom
  smtp_server = @config[:smtp_server]
  domain      = @config[:domain]

  if smtp_server && domain
    smtp = Net::SMTP.new(smtp_server, 25)
    smtp.enable_starttls
    smtp.start(domain) do
      smtp.send_message(message, mailto, mailto)
    end
  else
    puts "You must specify a SMTP server and domain to send email"
    exit
  end

end

result  = process_urls(urls)
msg     = compose_email(result)
mail_message(msg)
