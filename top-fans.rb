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

printf "#{fileList.length} posts"
count = 0

whoMap = {}
likeMap = {}
reblogMap = {}

fileList.each { | file |
  count += 1

  if count % 200 == 0
    printf "."
    $stdout.flush
  end

  File.open(file, 'r') { | content |
    reblog, likes = JSON.parse(content.read)

    reblog.values.each { | tuple |
      tuple.each { | who, post |
        whoMap[who] = 1 + (whoMap[who] || 0)
        reblogMap[who] = 1 + (reblogMap[who] || 0)
      }
    }

    likes.each { | who |
      whoMap[who] = 1 + (whoMap[who] || 0)
      likeMap[who] = 1 + (likeMap[who] || 0)
    }

  } 

}

top = [whoMap, likeMap, reblogMap].map { | which |
  which.sort_by { | who, count | count }.reverse[0..25]
}.transpose

printf "\n %-31s %-30s %s\n", "total", "likes", "reblogs"
top.each { | row |
  row.each { | who, count |
    printf "%5d %-25s", count, who
  }
  printf "\n"
}
