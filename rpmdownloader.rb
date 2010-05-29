#!/usr/bin/ruby

require 'open-uri'
require 'rubygems'
gem 'nokogiri'
require 'nokogiri'

if not system('which wget > /dev/null 2>&1')
	puts "wget not found"
	exit 1
end

Signal.trap(:INT) do
	puts 'quit.'
	exit 0
end

sync = true

class Downloader
	def query; end
	def download( url )
		system("wget --connect-timeout=5 -t 5 -q -P . #{url}")
	end
end

class DownloaderRpmFind < Downloader
	BASE_URL = "http://rpmfind.net/linux/rpm2html/search.php"
	NAME = 'rpmfind.net'
	attr_reader :NAME

	def initialize( package_name, distro, arch )
		@package_name = package_name
		@distro = distro
		@arch = arch

		@query_url = BASE_URL + build_query
	end

	def build_query
		query = "?query=#{@package_name}&submit=Search+..."

		if @distro
			case @distro
			when /^fc/
				query += '&system=fedora'
			else
				query += "&system=#{@distro}"
			end
		end

		if @arch
			case @arch
			when 'x86_64'
				query += '&arch=x86_64'
			when /i\d86/
				query += '&arch=i386'
			else
				query += "&arch=#{@arch}"
			end
		end

		return query
	end

	def query
		html = open(@query_url)
		doc = Nokogiri::HTML(html)
		rpm_urls = doc.css('a').map{|a|a.attributes['href'].to_s}.delete_if do |href|
			not href[/\.rpm$/]
		end

		if @distro
			rpm_urls.reject! do |url|
				not url.include?(".#{@distro}.")
			end
		end
		if @arch
			rpm_urls.reject! do |url|
				not url.include?(".#{@arch}.")
			end
		end

		return rpm_urls
	end
end

if not [1,2,3].include? ARGV.size
	puts "usage: #{File.basename $0} <package_name> [<distribution>] [<arch>]"
	exit 1
end

package_name = ARGV[0]
distro = ARGV[1]
arch = ARGV[2]

rpmfind = DownloaderRpmFind.new(package_name, distro, arch)

printf("querying to %s...", rpmfind.NAME)
rpm_urls = rpmfind.query()
puts 'done.'

if rpm_urls.size == 0
	puts "No rpm package found. exit."
	#puts doc
	exit 0
end

puts "#{rpm_urls.size} rpm found."
rpm_urls.each_with_index do |url, i|
	puts "#{i+1}\t#{File.basename(url)}"
end

print 'Enter a number to download> '
n = STDIN.gets.to_i

if n <= 0 or n > rpm_urls.size
	STDERR.puts 'Out of range. abort.'
	exit 1
end

puts 'downloading using wget...(will take a while)'
ret = rpmfind.download(rpm_urls[n-1])

if ret
	puts "\t#{File.basename(rpm_urls[n-1])} downloaded"
	puts 'done.'
else
	STDERR.puts 'wget failed'
	exit 1
end

# vim: ts=4
