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
require 'time'
require 'net/smtp'
if Gem::Specification::find_all_by_name('curb').any?
  require 'curb'
else
  puts "ERROR: Curb gem not found\n\n"
  exit
end

options   = {}
optparser = OptionParser.new do |opts|
  opts.banner = "Usage: urlcheck.rb [options]"
  opts.on("-c", "--config_file FILE", "Path to YAML config file") do |option|
    options[:config_file] = option
  end
  opts.on("-m", "--markers", "Send marker emails every hour") do |option|
    options[:marker]      = true
  end
  opts.on("-d", "--debug", "Always send mail") do |option|
    options[:debug]       = true
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
  config_file = (options[:config_file] && File.exists?(options[:config_file])) ? options[:config_file] : "#{File.dirname(__FILE__)}/urlcheck.yml"
  config      = YAML.load_file(config_file)
rescue Errno::ENOENT => e
  puts "Could not find config file"
  exit
end
@marker       = options[:marker]
@debug        = options[:debug]
@settings     = config["settings"].each_with_object({}) { |(k,v),memo| memo[k.to_sym] = v }
urls          = config["urls"]
@status_file  = @settings[:status_file] || './urlcheck.status'
@dirty        = false

def process_urls(urllist)
  urllist.each_with_object({}) do |line, coll|
    coll[line["url"]] = response_for(line["url"], line["code"])
  end
end

def response_for(url, code)
  status = ''
  begin
    ret = Curl.get(URI.encode(url))
    if ret.response_code && ret.response_code == code.to_i
      status = "OK"
    else
      # Code was different than expected
      status = "CODE_MISMATCH"
      @dirty = true
    end
  rescue Curl::Err::SSLPeerCertificateError => e
    if code.to_i == 000
      # 000 is Curl's "server's up, but not responding on SSL"
      status = "NOSSL EXPECTED"
    else
      # SSL was expected at this URL
      status = "SSLFAIL"
      @dirty = true
    end
  rescue Curl::Err::HostResolutionError => e
    puts "ERROR: #{url}: #{e}"
  rescue Curl::Err::ConnectionFailedError => e
    puts "ERROR: Could not connect: #{e}"
  end
  status
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

def current_status
  status = ''
  if File.exists?(@status_file)
    f = File.open(@status_file, 'r')
    status = f.first
    f.close
  end
  status
end

def set_status
  File.open(@status_file, 'w', 0600) do |f|
    f.write(@dirty ? "FAIL" : "OK")
    f.close
  end
end

def send_mail?
  @debug || @dirty || send_markers?
end

def send_markers?(time = Time.now)
  min = time.to_a[1]
  @markers && (min < 5 || (min > 55 && min < 60))
end

def mail_message(message)
  send_message(message) if send_mail?
end

def send_message(message)
  mailfrom    = @settings[:mail_from]    || ENV['USER']
  mailto      = @settings[:mail_to]      || mailfrom
  smtp_server = @settings[:smtp_server]
  domain      = @settings[:domain]

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
set_status
msg     = compose_email(result)
mail_message(msg)
