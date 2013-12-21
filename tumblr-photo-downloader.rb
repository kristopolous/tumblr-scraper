require 'rubygems'
require 'bundler'
require 'digest/md5'
Bundler.require

$site = ARGV[0]
$site = $site.split('/').pop
directory = ARGV[1] ? ARGV[1] : $site
$queue = Queue.new
$badFile = Queue.new
$useLogs = true
$getPages = true

if $site.nil? || $site.empty?
  puts
  puts "Usage: #{File.basename(__FILE__)} URL [directory to save in]"
  puts "eg. #{File.basename(__FILE__)} jamiew.tumblr.com"
  puts "eg. #{File.basename(__FILE__)} jamiew.tumblr.com ~/pictures/jamiew-tumblr-images/"
  puts
  exit 1
end

concurrency = 2

# Create the directory from the base directory AND the tumblr site
directory = [directory, $site].join('/')

# Create a log and graph directory
logs = [directory, 'logs'].join('/')
graphs = [directory, 'graphs'].join('/')

puts "Downloading photos from #{$site.inspect}, concurrency=#{concurrency} ..."

# Make the download directory
FileUtils.mkdir_p(directory)

# Make the log directory
FileUtils.mkdir_p(logs)
FileUtils.mkdir_p(graphs)

threads = []
num = 50
start = 0
$allImages = []

def parsefile(doc)
  images = (doc/'post photo-url').select{|x| x if x['max-width'].to_i == 1280 }
  posts = (doc/'post').map {|x| x['url']}
  image_urls = images.map {|x| x.content }

  # Eliminate duplicate images.
  image_urls.sort!
  image_urls.uniq!
  
  # Eliminate images we've already downloaded
  image_urls = image_urls - $allImages

  # Add this to the list
  $allImages += image_urls
  $allImages += posts

  posts.each do | url |
    $queue << [:page, url]
  end

  image_urls.each do |url|
    $queue << [:image, url]
  end
  [images, image_urls]
end

if $useLogs
  Dir.glob("#{logs}/*") { | file |

    if file == "badurl"

      File.open(file, 'r') { | content |
        # Start the list with the bad images
        $allImages = content.split('\n')
      }

    else
      File.open(file, 'r') { | content |
        images, count = parsefile Nokogiri::XML.parse(content)

        if count.length > 0
          puts ">> #{file} +#{count.length}"
        else
          puts ">> #{file} +#{count.length} (removed)"
          File.delete(file) if count.length == 0
        end
      }

    end
  }
end

def graphGet(file)
  file.match(/.GET...([^']*)/) { | x | 
    url = ['http://', $site, x].join('')
    puts url
  }
end

concurrency.times do 
  threads << Thread.new {
    Thread.abort_on_exception = true

    loop {
      begin
        type, url = $queue.pop
        break if url == "STOP"
      rescue
        puts "Queue failure, trying again, #{$!}"
        next
      end
      
      filename = url.split('/').pop

      if type == :image
        unless File.exists?("#{directory}/#{filename}")
          loop {
            begin
              file = Mechanize.new.get(url)
              file.save_as("#{directory}/#{filename}")
              puts "#{$allImages.length - $queue.length}/#{$allImages.length} #{$site} #{filename}"
              break

            # This often arises from requesting too many things.
            # If this is the case, let's try to just save the files again.
            rescue Mechanize::ResponseCodeError => e
              # Timeout error
              if Net::HTTPResponse::CODE_TO_OBJ[e] == 403
                puts "Bad File"
                $badFile << url
                break
              elsif Net::HTTPResponse::CODE_TO_OBJ[e] == 408
                # Take a break, man.
                sleep 1
                next
              else
                break
              end
              
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
      elsif type == :page
        unless File.exists?("#{graphs}/#{filename}")
          loop {
            begin
              file = Mechanize.new.get(url)
              file.save_as("#{graphs}/#{filename}")
              graphGet(file.body)
              break

            # This often arises from requesting too many things.
            # If this is the case, let's try to just save the files again.
            rescue Mechanize::ResponseCodeError => e
              # Timeout error
              if Net::HTTPResponse::CODE_TO_OBJ[e] == 403
                puts "Bad File"
                $badFile << url
                break
              elsif Net::HTTPResponse::CODE_TO_OBJ[e] == 408
                # Take a break, man.
                sleep 1
                next
              else
                break
              end
              
            rescue
              puts "Error getting file (#{url}), #{$!}"
              break

            end
          }
        end
      end
    }
  }
end

if $getPages
  loop do
    page_url = "http://#{$site}/api/read?type=photo&num=#{num}&start=#{start}"

    page = ''
    loop {
      begin
        page = Mechanize.new.get(page_url)
        break

      rescue Mechanize::ResponseCodeError => e
        if Net::HTTPResponse::CODE_TO_OBJ[e] == 404
          puts "Fatal Error"
          exit
        end

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
      images, added = parsefile doc

      puts "| #{page_url} +#{added.count}"

      # If this file added nothing, then break here and don't save it.
      if added.count == 0
        puts "Guessing that we have everything else. Not downloading any more pages. Waiting for images."
        break
      end
      
      # Log the content that we are getting
      File.open(logFile, 'w') { | f |
        f.write(doc.to_s)
      }

      if images.count < num
        puts "All pages downloaded. Waiting for images"
        break
      end
    end

    start += num
  end
end

concurrency.times do 
  $queue << [:control, "STOP"]
end

threads.each{|t| t.join }

puts "Ok done. Adding 403s to blacklist"
loop {
  break if $badFile.empty?
  url = $badFile.pop

  File.open("#{logs}/badurl", "w+") do | f1 |
    f1.write(url)
  end
}
