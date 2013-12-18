require 'rubygems'
require 'bundler'
require 'digest/md5'
Bundler.require

site = ARGV[0]
site = site.split('/').pop
directory = ARGV[1] ? ARGV[1] : site
$queue = Queue.new
$badFile = Queue.new

if site.nil? || site.empty?
  puts
  puts "Usage: #{File.basename(__FILE__)} URL [directory to save in]"
  puts "eg. #{File.basename(__FILE__)} jamiew.tumblr.com"
  puts "eg. #{File.basename(__FILE__)} jamiew.tumblr.com ~/pictures/jamiew-tumblr-images/"
  puts
  exit 1
end

concurrency = 2

# Create the directory from the base directory AND the tumblr site
directory = [directory, site].join('/')

# Create a log directory
logs = [directory, 'logs'].join('/')

puts "Downloading videos from #{site.inspect}, concurrency=#{concurrency} ..."

# Make the download directory
FileUtils.mkdir_p(directory)

# Make the log directory
FileUtils.mkdir_p(logs)

threads = []
num = 50
start = 0
$allImages = []

def parsefile(doc)
  all = [] 
  doc.scan(/url="([^"]*)"/) { | list | 
    list.each { | x |
      all << x
      $queue << x
    }
  }
  [all, all]
end
=begin
Dir.glob("#{logs}/*") { | file |
  if file == "badurl"

    File.open(file, 'r') { | content |
      # Start the list with the bad images
      $allImages = content.split('\n')
    }

  else
    File.open(file, 'r') { | content |
      images, count = parsefile Nokogiri::XML.parse(content)
      puts ">> #{file} +#{count.length}"
    }
  end
}
=end
concurrency.times do 
  threads << Thread.new {
    Thread.abort_on_exception = true

    loop {
      begin
        url = $queue.pop
        break if url == "STOP"
      rescue
        puts "Queue failure, trying again, #{$!}"
        next
      end
      
      videoList = []
      page = Mechanize.new.get(url)
      page.body.scan(/src=.x22([^\\]*)/) { | list |
        list.each { | x |
          if x.match(/video_file/)
            videoList << x
            $allImages << x
          end
        }
      }

      videoList.each { | url |
        filename = url.split('/').pop + ".mp4"
        
        unless File.exists?("#{directory}/#{filename}")
          loop {
            begin
              puts "#{$allImages.length - $queue.length}/#{$allImages.length} #{site} #{filename}"
              file = Mechanize.new.get(url)
              file.save_as("#{directory}/#{filename}")
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
      }
    }
  }
end

loop do
  page_url = "http://#{site}/api/read?type=video&num=#{num}&start=#{start}"

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

  md5 = Digest::MD5.hexdigest(page.body)
  logFile = [logs, md5].join('/')

#  unless File.exists?(logFile)
    # Log the content that we are getting
#    File.open(logFile, 'w') { | f |
#      f.write(doc.to_s)
#    }

    images, added = parsefile page.body

    puts "| #{page_url} +#{added.count}"
    
    if images.count < num
      puts "All pages downloaded. Waiting for videos"
      break
    end
#  end

  start += num
end

concurrency.times do 
  $queue << "STOP"
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
