#
# top-fans will take a collapsed blog (see note-collapse)
# read through the posts, and then print out the top rebloggers
# and fans from that blog
#
require 'rubygems'
require 'bundler'
Bundler.require

$start = Time.new
Dir.chdir(ARGV[0])
fileList = Dir["*.json"]

puts "#{fileList.length} posts"
puts " time | total | remain"
count = 0

whoMap = {}

fileList.each { | file |
  count += 1

  if count % 200 == 0
    duration = Time.new - $start
    ttl = (duration / (count.to_f / fileList.length.to_f)).to_i
    togo = "%02d:%02d" % [(ttl / 60).to_i, ttl % 60]
    lapsed = "%02d:%02d" % [(duration / 60).to_i, (duration % 60).to_i]
    remain = "%6d" % [fileList.length - count]

    puts "#{lapsed} | #{togo} | #{remain}"
    puts "-----\n#{ARGV[0]}" if count % 2000 == 0
  end

  File.open(file, 'r') { | content |
    reblog, likes = JSON.parse(content.read)

    reblog.values.each { | tuple |
      tuple.each { | who, post |
        whoMap[who] = 0 unless whoMap.has_key? who
        whoMap[who] += 1
      }
    }

    likes.each { | who |
      whoMap[who] = 0 unless whoMap.has_key? who
      whoMap[who] += 1
    }

  } 

}
sorted = whoMap.sort_by { | who, count | count }.reverse

sorted.each { | who, count |
  if count > 10 
    puts "#{count} #{who}"
  end
}
