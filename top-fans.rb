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

header = true
if ARGV.length > 1
  header = false
end

printf "#{fileList.length} posts" if header
count = 0

limit = (ARGV[1] || 25).to_i

whoMap = {}
likeMap = {}
reblogMap = {}

fileList.each { | file |
  count += 1

  if count % 200 == 0 and header
    printf "."
    $stdout.flush
  end

  File.open(file, 'r') { | content |
    JSON.parse(content.read)[0..20].each { | entry |
      if entry.is_a?(String)
        who = entry
        likeMap[who] = 1 + (likeMap[who] || 0)
      else
        source, who, post = entry
        reblogMap[who] = 1 + (reblogMap[who] || 0)
      end
      whoMap[who] = 1 + (whoMap[who] || 0)
    }
  } 
}

top = [whoMap, likeMap, reblogMap].map { | which |
  which.sort_by { | who, count | count }.reverse[0..limit]
}.transpose

if header
  printf "\n %-31s %-30s %s\n", "total", "likes", "reblogs"
  top.each { | row |
    row.each { | who, count |
      printf "%5d %-25s", count, who
    }
    printf "\n"
  }
else
  top.each { | row |
    print "#{row[0][0]}.tumblr.com\n"
  }
end
