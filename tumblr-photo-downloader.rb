require 'rubygems'
require 'bundler'
Bundler.require

site = ARGV[0]
directory = ARGV[1] ? ARGV[1] : site

if site.nil? || site.empty?
  puts
  puts "Usage: #{File.basename(__FILE__)} URL [directory to save in]"
  puts "eg. #{File.basename(__FILE__)} jamiew.tumblr.com"
  puts "eg. #{File.basename(__FILE__)} jamiew.tumblr.com ~/pictures/jamiew-tumblr-images/"
  puts
  exit 1
end

concurrency = 8

# Create the directory from the base directory AND the tumblr site
directory = [directory, site].join('/')

# Create a log directory
logs = [directory, 'logs'].join('/')

puts "Downloading photos from #{site.inspect}, concurrency=#{concurrency} ..."

# Make the download directory
FileUtils.mkdir_p(directory)

FileUtils.mkdir_p(logs)

num = 50
start = 0
allImages = []

loop do
  url = "http://#{site}/api/read?type=photo&num=#{num}&start=#{start}"
  page = Mechanize.new.get(url)
  doc = Nokogiri::XML.parse(page.body)

  images = (doc/'post photo-url').select{|x| x if x['max-width'].to_i == 1280 }
  image_urls = images.map {|x| x.content }

  already_had = 0
  
  # Eliminate duplicate images.
  image_urls.sort!
  image_urls.uniq!
  
  # Eliminate images we've already downloaded
  image_urls = image_urls - allImages

  # Add this to the list
  allImages << image_urls

  image_urls.each_slice(concurrency).each do |group|
    threads = []
    group.each do |url|
      threads << Thread.new {
        begin
          file = Mechanize.new.get(url)
          filename = File.basename(file.uri.to_s.split('?')[0])
          
          if File.exists?("#{directory}/#{filename}")
            puts "Already have #{url}"
            already_had += 1
          else
            puts "Saving photo #{url}"
            file.save_as("#{directory}/#{filename}")
          end

        rescue Mechanize::ResponseCodeError
          puts "Error getting file, #{$!}"
        end
      }
    end
    threads.each{|t| t.join }
  end

  puts "#{images.count} images found (num=#{num})"
  
  if images.count < num
    puts "Our work here is done"
    break
  elsif already_had == num
    puts "Had already downloaded the last #{already_had} of #{num} most recent images - done."
    break
  else
    start += num
  end

end
