#!/usr/bin/env ruby
#
# profile-grep will take a stdin list of collapsed graphs (see note-collapse)
# read through the posts, and then take the arguments from the command line
# and print out the posts which have the percentage of likes and reblogs
# matching the pattern
#
# By using stdin, this allows one to read over multiple blogs.
#
require 'rubygems'
require 'bundler'
Bundler.require

$start = Time.new

count = 0

qstr = ARGV[0]

puts "Searching for #{qstr}"
resultsMap = {}

$stdin.each_line { | file |
  file.strip!
  count += 1

  if count % 200 == 0
    $stderr.putc "."
  end

  File.open(file, 'r') { | content |
    keyout = file.gsub('graphs', 'post').gsub('.json','').gsub('/raid/tumblr','http:/')
    resultsMap[keyout] = 0
    json = JSON.parse(content.read)
    map = {}

    json.each { | entry |
      if entry.is_a?(String)
        who = entry
      else
        who, source, post = entry
        who = source
      end

      unless map.key? who
        map[who] = true
        unless (who =~ /#{qstr}/).nil?
          resultsMap[keyout] += 1.0
        end
      end
    }
    resultsMap[keyout] /= [json.length, 70].max.to_f
  } 
}

resultsMap.sort_by{|k, v| v }.each { | name, count |
  printf "%5.3f %-25s\n", count * 100, name unless count == 0
}
