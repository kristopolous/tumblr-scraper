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

def similar(list)
  limit = 35

  whoMap = {}
  likeMap = {}
  reblogMap = {}
  list.split(',').each { | row |
    blog, entry = row.split(';') 

    file = "/raid/tumblr/#{blog}.tumblr.com/graphs/#{entry}.json"

    count += 1

    File.open(file, 'r') { | content |
      json=JSON.parse(content.read)
      metric = Math.sqrt(1.0/json.length)

      json[0..30].each { | entry |
        if entry.is_a?(String)
          who = entry
          likeMap[who] = metric + (likeMap[who] || 0.0)
        else
          who, source, post = entry
          who=source
          reblogMap[who] = metric + (reblogMap[who] || 0.0) 
        end
        whoMap[who] = metric + (whoMap[who] || 0.0)
      }
    } 
  }

  limit = [whoMap.length, likeMap.length, reblogMap.length, limit].min - 1

  top = [whoMap, likeMap, reblogMap].map { | which |
    which.sort_by { | who, count | count }.reverse[0..limit]
  }.transpose
  top
end
