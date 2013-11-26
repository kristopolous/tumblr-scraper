require 'rubygems'
require 'bundler'
require 'digest/md5'
Bundler.require

site = ARGV[0]
site = site.split('/').pop
directory = ARGV[1] ? ARGV[1] : site
queue = Queue.new

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

# Make the log directory
FileUtils.mkdir_p(logs)

num = 50
start = 0
allImages = []

threads = []
concurrency.times do 
  threads << Thread.new {
    loop {
      url = queue.pop
      break if url == 'STOP'
      
      filename = url.split('/').pop
      
      if File.exists?("#{directory}/#{filename}")
        # puts "#{queue.length} Already have #{url}"
      else
        loop {
          begin
            file = Mechanize.new.get(url)
            file.save_as("#{directory}/#{filename}")
            puts "#{allImages.length - queue.length}/#{allImages.length} #{site} #{filename}"
            break

          # This often arises from requesting too many things.
          # If this is the case, let's try to just save the files again.
          rescue Timeout::Error
            # Take a break, man.
            sleep 1
            next

          rescue
            puts "Error getting file (#{url}), #{$!}"
            break
          end
        }
      end
    }
  }
end

loop do
  url = "http://#{site}/api/read?type=photo&num=#{num}&start=#{start}"

  page = ''
  loop {
    begin
      page = Mechanize.new.get(url)
      break

    rescue
      puts "Error getting file (#{url}), #{$!} - retrying"
      sleep 1
      next
    end
  }

  md5 = Digest::MD5.hexdigest(page.to_s)

  # Log the content that we are getting
  File.open([logs, md5].join('/'), 'w') { | f |
    f.write(page.to_s)
  }

  doc = Nokogiri::XML.parse(page.body)

  images = (doc/'post photo-url').select{|x| x if x['max-width'].to_i == 1280 }
  image_urls = images.map {|x| x.content }

  # Eliminate duplicate images.
  image_urls.sort!
  image_urls.uniq!
  
  # Eliminate images we've already downloaded
  image_urls = image_urls - allImages

  # Add this to the list
  allImages += image_urls

  image_urls.each do |url|
    queue << url
  end

  puts ">> +#{images.count} images found (num=#{num} :: start at #{start})"
  
  if images.count < num
    puts "All pages downloaded. Waiting for images"
    break
  else
    start += num
  end
end

concurrency.times do 
  queue << 'STOP'
end

threads.each{|t| t.join }
