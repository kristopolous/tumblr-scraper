#!/usr/bin/env ruby
#
# top-fans will take a stdin list of collapsed graphs (see note-collapse)
# read through the posts, and then print out the top rebloggers
# and fans from all those in stdin.
#
# By using stdin, this allows one to read over multiple blogs.
#
# This is currently limited to a value set below (see the line with ARGV[0])
#
# Usage: 
#
#   You need to feed json files into stdin to get useful results. The
#   json files are the output from the note-collapse upon the graph
#   directory.
#
#   For instance:
#
#   $ find /large/tumblr/retrodust.tumblr.com/notes -name \*.json | ./top-fans.rb
#
require 'rubygems'
require 'bundler'
Bundler.require

$start = Time.new

header = true
if ARGV.length > 0
  header = false
end

count = 0

limit = (ARGV[0] || 35).to_i

whoMap = {}
likeMap = {}
reblogMap = {}
flatMap = {}
scale = 20.0

$stdin.each_line { | file |
  file.strip!
  count += 1

  if count % 200 == 0 and header
    $stderr.putc "."
  end

  File.open(file, 'r') { | content |
    json = JSON.parse(content.read)
    metric = Math.sqrt(1.0 / json.length)

    json[0..30].each { | entry |
      if entry.is_a?(String)
        who = entry
        next if file.include?(who) 
        likeMap[who] = metric + (likeMap[who] || 0.0)
      else
        who, source, post = entry
        who = source
        next if file.include?(who) 
        reblogMap[who] = metric + (reblogMap[who] || 0.0) 
      end
      whoMap[who] = metric + (whoMap[who] || 0.0)
      flatMap[who] = (flatMap[who] || 0) + 1.0 / scale
    }
  } 
}

limit = [whoMap.length, likeMap.length, reblogMap.length, flatMap.length, limit].min - 1

top = [whoMap, likeMap, reblogMap, flatMap].map { | which |
  which.sort_by { | who, count | count }.reverse[0..limit]
}.transpose

if header
  printf "\n %-31s %-30s %-30s %s\n", "total", "likes", "reblogs", "flat"
  top.each { | row |
    row.each { | who, count |
    printf "%5d %-25s", count * scale, who
    }
    printf "\n"
  }
else
  top.each { | row |
    print "#{row[0][0]}.tumblr.com\n"
  }
end
