#
# top-fans will take a stdin list of collapsed graphs (see note-collapse)
# read through the posts, and then print out the top rebloggers
# and fans from all those in stdin.
#
# By using stdin, this allows one to read over multiple blogs.
#
require 'rubygems'
require 'bundler'
Bundler.require

def find_similar(list)
  limit = 35

  whoMap = {}
  count = 0
  list.split(',').each { | row |
    blog, entry = row.split(';') 

    file = "/raid/tumblr/#{blog}.tumblr.com/graphs/#{entry}.json"

    count += 1

    File.open(file, 'r') { | content |
      json=JSON.parse(content.read)
      metric = Math.sqrt(1.0/json.length)

      json[0..1000].each { | entry |
        if entry.is_a?(String)
          who = entry
        else
          who, source, post = entry
          who=source
        end
        whoMap[who] = metric + (whoMap[who] || 0.0)
      }
    } 
  }

  whoMap.sort_by { | who, count | (1 - count) }[0..limit]
end
