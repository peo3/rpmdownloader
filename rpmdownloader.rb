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

STDOUT.sync = true

class Downloader
	def initialize( package_name, distro, arch )
		@package_name = package_name
		@distro = distro
		@arch = arch
	end
	def query; end
	def download( url )
		system("wget --connect-timeout=5 -t 5 -q -P . #{url}")
	end
end

class DownloaderRpmFind < Downloader
	BASE_URL = "http://rpmfind.net/linux/rpm2html/search.php"
	NAME = 'rpmfind.net'
	attr_reader :NAME

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
		url = BASE_URL + build_query

		# rpmfind.net sometimes returns different results
		n_try = 3

		rpm_urls = nil
		n_try.times do
			html = open(url)
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

			break if rpm_urls.size > 0
		end

		return rpm_urls
	end
end

class DownloaderFedoraArchives < Downloader
	BASE_URL = "http://archives.fedoraproject.org/pub/archive/fedora/linux"
	NAME = 'archives.fedoraproject.org'
	attr_reader :NAME
	SUPPORTED_ARCHS = ['i386', 'x86_64', 'ppc', 'ppc64']

	def initialize( package_name, distro, arch )
		super

		if arch.nil?
			raise 'Please choose one arch in %s' % [SUPPORTED_ARCHS.join(', ')]
		end

		if distro =~ /fc(\d+)/
			@version = $1.to_i
		else
			raise 'Cannot get version number'
		end
	end

	def query
		if @arch.nil?
			archs = SUPPORTED_ARCHS
		else
			archs = [@arch]
		end

		query_urls = []
		archs.each do |arch|
			if [9].include?(@version)
				query_urls << BASE_URL + "/releases/%d/Everything/%s.newkey/os/Packages/" % [@version, arch]
			else
				query_urls << BASE_URL + "/releases/%d/Everything/%s/os/Packages/" % [@version, arch]
			end

			if [8, 9].include?(@version)
				query_urls << BASE_URL + "/updates/%d/%s.newkey/" % [@version, arch]
			else
				query_urls << BASE_URL + "/updates/%d/%s/" % [@version, arch]
			end
		end
		#p query_urls

		rpm_urls = []
		query_urls.each do |url|
			html = open(url)
			doc = Nokogiri::HTML(html)
			found_pkgs = doc.css('a').map{|a|a.attributes['href'].to_s}.delete_if do |href|
				not href[/^#{@package_name}-[0-9]/]
			end
			rpm_urls += found_pkgs.map{|_url| url + _url}
		end
		#p rpm_urls
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

repos = [ DownloaderRpmFind, DownloaderFedoraArchives ]
repos.each do |repo|
	downloader = repo.new(package_name, distro, arch)

	print "Querying to %s..." % [downloader.class::NAME]
	begin
		rpm_urls = downloader.query()
	rescue
		puts 'Query failed. Trying a next repository.'
		next
	end
	puts 'done.'

	if rpm_urls.size == 0
		puts "No rpm package found. Trying a next repository."
		next
	end

	puts "#{rpm_urls.size} rpm found."
	rpm_urls.each_with_index do |url, i|
		puts "#{i+1}\t#{File.basename(url)}"
	end

	begin
		print 'Enter a number to download> '
		n = STDIN.gets.to_i

		if n <= 0 or n > rpm_urls.size
			puts 'Out of range.'
		end
	end while not (n > 0 and n <= rpm_urls.size)

	puts 'Downloading using wget...(will take a while)'
	ret = downloader.download(rpm_urls[n-1])

	if ret
		puts "\t#{File.basename(rpm_urls[n-1])} downloaded"
		puts 'done.'
		break
	else
		puts 'wget failed. Trying next repository.'
	end
end

# vim: ts=4
