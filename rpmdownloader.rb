#!/usr/bin/ruby

require 'open-uri'
require 'rubygems'
gem 'nokogiri'
require 'nokogiri'

if not [1,2,3].include? ARGV.size
  STDOUT.puts "usage: #{File.basename $0} <package_name> [<distribution>] [<arch>]"
  exit 1
end

if not system('which wget > /dev/null 2>&1')
  STDOUT.puts "wget not found"
  exit 1
end

package_name = ARGV[0]
distribution = ARGV[1]
architecture = ARGV[2]

system = ''
arch   = ''
if distribution
  case distribution
  when /^fc/
    system = '&system=fedora'
  else
    system = "&system=#{distribution}"
  end
end

if architecture
  case architecture
  when 'x86_64'
    arch='&arch=x86_64'
  when /i\d86/
    arch='&arch=i386'
  else
    arch="&arch=#{architecture}"
  end
end

Signal.trap(:INT) do
  STDOUT.puts 'quit.'
  exit 0
end

url = "http://rpmfind.net/linux/rpm2html/search.php?query=#{package_name}&submit=Search+...#{system}#{arch}"
STDOUT.printf 'querying to rpmfind.net...'
#STDOUT.puts url
STDOUT.flush

html = open(url)
doc = Nokogiri::HTML(html)
rpm_urls = doc.css('a').map{|a|a.attributes['href'].to_s}.delete_if do |href|
  not href[/\.rpm$/]
end
if distribution
  rpm_urls.reject! do |url|
    not url.include?(".#{distribution}.")
  end
end
if architecture
  rpm_urls.reject! do |url|
    not url.include?(".#{architecture}.")
  end
end
STDOUT.puts 'done.'

if rpm_urls.size == 0
  puts "0 rpm found. exit."
  #puts doc
  exit 0
end

STDOUT.puts "#{rpm_urls.size} rpm found."
rpm_urls.each_with_index do |url, i|
  puts "#{i+1}\t#{File.basename(url)}"
end

STDOUT.print 'Enter a number to download> '
STDOUT.flush
n = STDIN.gets.to_i

if n <= 0
  STDERR.puts 'abort.'
  exit 1
end

puts 'downloading using wget...(will take a while)'
STDOUT.flush
#rpm_urls.each do |url|
#  system("wget -q -P . #{url}")
#  puts "\t#{File.basename(url)} downloaded"
#  STDOUT.flush
#end

ret = system("wget --connect-timeout=5 -t 5 -q -P . #{rpm_urls[n-1]}")
if ret
  puts "\t#{File.basename(rpm_urls[n-1])} downloaded"
  STDOUT.puts 'done.'
else
  STDERR.puts 'wget failed'
  exit 1
end
