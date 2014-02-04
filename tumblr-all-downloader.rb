require 'rubygems'
require 'bundler'
require 'yaml'
require 'digest/md5'
Bundler.require

$site = ARGV[0]
$site = $site.split('/').pop
$start = Time.new
directory = ARGV[1] ? ARGV[1] : $site
$queue = Queue.new
$backlog = Queue.new
$badFile = Queue.new
$maxgraph = 10
$bytes = 0

concurrency = 4

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
$allImages = []
$connection = Mechanize.new

def download(url, local = '')
  return [false, 0] if local.length > 0 and File.exists?(local)

  len = 72
  page = false
  tries = 6

  loop {
    tries -= 1

    begin
      page = $connection.get(url)
      break

    rescue Mechanize::ResponseCodeError => e
      if e.page.code == "403"
        return [false, 403]

      elsif e.response_code == "404"
        $badFile << url
        return [false, 404]

      elsif e.response_code == "408"
        puts "Error (#{url}), #{$!} - waiting a second"

        if tries > 0
          sleep 1
          next
        end

        break
      end


    rescue Timeout::Error
      puts "Error (#{url}), #{$!} - retrying"

      if tries > 0
        sleep 1
        next
      end

      break

    rescue Exception => ex
      puts "Error (#{url}), #{$!}"

      if ex.class == SocketError
        puts "Maybe the site is gone?"
        exit -1
      end

      if tries > 0
        puts "Trying again (#{tries} left)"
        sleep 1
        next
      end

      break
    end
  }

  if page and page.body
    $bytes += page.body.length
    duration = Time.new - $start
    mb = $bytes / (1024.00 * 1024.00)
    speed = ($bytes / duration) / 1024
    puts "%4d %4.2fM %.0f:%02d %3.0fK %s %s" % [$queue.length + $maxgraph * $backlog.length, mb, (duration / 60).floor, duration.to_i % 60, speed, url.slice(-[len, url.length].min, len), local.slice(-[len, local.length].min, len)]
    STDOUT.flush

    page.save_as(local) if local.length > 0
  else
    puts YAML::dump(page)
    exit
  end
 
  [true, page]
end

def parsevideo(page)
  all = [] 
  page.scan(/url="([^"]*)"/) { | list | 
    list.each { | x |
      all << x
      $queue << [:video, x]
    }
  }

  doc = Nokogiri::XML.parse(page)
  posts = (doc/'post').map {|x| x['url']}
  posts.each do | url |
    $backlog << [:page, url]
  end

  all
end

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
    $backlog << [:page, url]
  end

  image_urls.each do |url|
    $queue << [:image, url]
  end

  [images, image_urls]
end

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


def graphGet(file)
  file.scan(/'(\/notes\/[^\']*)',/) { | x | 
    return ['http://', $site, x].join('')
  }
  false
end

concurrency.times do 
  threads << Thread.new {

    # Make sure we know about failures.
    Thread.abort_on_exception = true

    loop {
      begin
        # Only get the low-priority requests if the high
        # priority ones are done
        if $queue.empty?
          type, url = $backlog.pop
        else
          type, url = $queue.pop
        end

        #puts "#{$queue.length} [Queue] #{type} #{url}"
        break if url == "STOP"
      rescue
        puts "Queue failure, trying again, #{$!}"
        next
      end
      
      filename = url.split('/').pop

      if type == :video
        videoList = []
        count = 0
        success, page = download(url)

        if success
          page.body.scan(/src=.x22([^\\]*)/) { | list |
            list.each { | x |
              videoList << x if x.match(/video_file/)
            }
          }

          videoList.each { | url |
            count += 1
            filename = url.split('/').pop + ".mp4"
            
            unless File.exists?("#{directory}/#{filename}")
              File.open("#{directory}/vids", 'a') { | f |
                realurl=`curl -sI #{url} | grep ocation | awk ' { print $2 } '`
                f.write("#{realurl.gsub(/#.*/, '')}")
                puts "[Video] #{count} / #{videoList.length}"
              }
            end
          }
        end

      elsif type == :image
        success, file = download(url, "#{directory}/#{filename}")

      elsif type == :page
        page = 0
        loop {
          fname = "#{graphs}/#{filename}.#{page}"
          
          success, file = download(url, fname)
          url = graphGet(file.body) if success

          ## Just get the recent history... no need to go crazy
          break unless url and success and page < $maxgraph

          page += 1
        }
      end
    }
  }
end

num = 50
start = 0
loop do
  page_url = "http://#{$site}/api/read?type=photo&num=#{num}&start=#{start}"

  success, page = download(page_url)

  if !success
    puts "Failed to get #{page_url}"
    break
  end

  doc = Nokogiri::XML.parse(page.body)
  md5 = Digest::MD5.hexdigest(page.body)
  logFile = [logs, md5].join('/')

  break if File.exists?(logFile)

  images, added = parsefile doc

  # If this file added nothing, then break here and don't save it.
  break if added.count == 0
  
  # Log the content that we are getting
  File.open(logFile, 'w') { | f | f.write(doc.to_s) }

  break if images.count < num

  start += num
end
puts "All image feeds downloaded."

num = 50
start = 0
loop do
  page_url = "http://#{$site}/api/read?type=video&num=#{num}&start=#{start}"

  success, page = download(page_url)

  if !success
    puts "Failed to get #{page_url}"
    break
  end

  md5 = Digest::MD5.hexdigest(page.body)
  logFile = [logs, md5].join('/')

  break if File.exists?(logFile)

  videos = parsevideo page.body
  start += num

  File.open(logFile, 'w') { | f | f.write(page.body) }
  
  break if videos.count < num
end

puts "All feeds downloaded."

concurrency.times do 
  $backlog << [:control, "STOP"]
end

threads.each { |t| t.join }

puts "Ok done. Adding 403s to blacklist"

File.open("#{logs}/badurl", "w+") { | f | 
  loop {
    break if $badFile.empty?
    f.write( $badFile.pop )
  }
}
