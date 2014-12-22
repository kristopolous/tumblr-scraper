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

def profile_grep(blog, qstr)
  resultsMap = {}

  count = 0
  if File.exist? blog + "/logs/posts.json"
    posts = JSON.parse(File.open(blog + "/logs/posts.json").read)
  else
    puts "Need to digest logs on #{blog}"
    []
  end

  posts.each { | value, key |
    count += 1
    file =  blog + "/graphs/#{value}.json"

    if count == 100
      break
    end

    next unless File.exist? file
     
    File.open(file, 'r') { | content |
      resultsMap[value] = 0
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
            resultsMap[value] += 1.0
          end
        end
      }
      resultsMap[value] /= [json.length, 70].max.to_f
    } 

  }

  finalMap = []
  resultsMap.sort_by{|k, v| v }.reverse.each { | name, count |
    finalMap << posts[name] unless count == 0
  }
  finalMap
end
