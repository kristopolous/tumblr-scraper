require 'rubygems'
require 'bundler'
require 'digest/md5'
Bundler.require

site = ARGV[0]
site = site.split('/').pop
directory = ARGV[1] ? ARGV[1] : site
$queue = Queue.new
$badFile = Queue.new

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
$allVideos = []

def parsefile(doc)
  all = [] 
  doc.scan(/url="([^"]*)"/) { | list | 
    list.each { | x |
      all << x
      $queue << x
      $allVideos << x
    }
  }
  all
end

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
          end
        }
      }

      videoList.each { | url |
        filename = url.split('/').pop + ".mp4"
        
        unless File.exists?("#{directory}/#{filename}")
          File.open('vids', 'a') { | f |
            realurl=`curl -sI #{url} | grep ocation | awk ' { print $2 } '`
            f.write("#{site} #{realurl.gsub(/#.*/, '')}")
            print '.'
            STDOUT.flush
          }
        end

        #puts "#{$allVideos.length - $queue.length}/#{$allVideos.length} #{site} #{filename}"
        #`wget --progress=dot -c -O #{directory}/#{filename} "#{url}"`
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

  unless File.exists?(logFile)
    # Log the content that we are getting
    File.open(logFile, 'w') { | f |
      f.write(page.body)
    }
  end

  videos = parsefile page.body

  puts "| #{page_url} +#{videos.count}"
  
  if videos.count < num
    puts "All pages downloaded. Waiting for videos"
    break
  end

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
