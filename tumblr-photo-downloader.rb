require 'rubygems'
require 'bundler'
require 'digest/md5'
Bundler.require

site = ARGV[0]
site = site.split('/').pop
directory = ARGV[1] ? ARGV[1] : site
$queue = Queue.new

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
$allImages = []

threads = []
concurrency.times do 
  threads << Thread.new {
    loop {
      url = $queue.pop
      break if url == "STOP"
      
      filename = url.split('/').pop
      
      unless File.exists?("#{directory}/#{filename}")
        loop {
          begin
            file = Mechanize.new.get(url)
            file.save_as("#{directory}/#{filename}")
            puts "#{$allImages.length - $queue.length}/#{$allImages.length} #{site} #{filename}"
            break

          # This often arises from requesting too many things.
          # If this is the case, let's try to just save the files again.
          rescue Timeout::Error
            # Take a break, man.
            sleep 1
            next

          else
            puts "Error getting file (#{url}), #{$!}"
            break
          end
        }
      end
    }
  }
end

def parsefile(doc)
  images = (doc/'post photo-url').select{|x| x if x['max-width'].to_i == 1280 }
  image_urls = images.map {|x| x.content }

  # Eliminate duplicate images.
  image_urls.sort!
  image_urls.uniq!
  
  # Eliminate images we've already downloaded
  image_urls = image_urls - $allImages

  # Add this to the list
  $allImages += image_urls

  image_urls.each do |url|
    $queue << url
  end
  [images, image_urls]
end

Dir.glob("#{logs}/*") { | file |
  File.open(file, 'r') { | content |
    puts ">> #{file}"
    parsefile Nokogiri::XML.parse(content)
  }
}

loop do
  page_url = "http://#{site}/api/read?type=photo&num=#{num}&start=#{start}"

  page = ''
  loop {
    begin
      page = Mechanize.new.get(page_url)
      break

    rescue
      puts "Error stream (#{page_url}), #{$!} - retrying"
      sleep 1
      next
    end
  }

  doc = Nokogiri::XML.parse(page.body)
  md5 = Digest::MD5.hexdigest(doc.to_s)
  logFile = [logs, md5].join('/')

  unless File.exists?(logFile)
    # Log the content that we are getting
    File.open(logFile, 'w') { | f |
      f.write(doc.to_s)
    }

    images, added = parsefile doc

    puts "| #{page_url}\n| #{md5} +#{added.count} images found (start at #{start})"
    
    if images.count < num
      puts "All pages downloaded. Waiting for images"
      break
    end
  end

  start += num
end

concurrency.times do 
  $queue << 'STOP'
end

threads.each{|t| t.join }
