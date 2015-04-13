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

def profile_grep(blogList, qstr)
  start = Time.new
  resultsMap = {}
  reg = Regexp.new(qstr)

  postList = []
  pathList = []
  count = 0
  which = 0
  blogList.split(',').each { | endpoint | 
    blog = '/raid/tumblr/' + endpoint + '.tumblr.com'
    postFile = blog + "/logs/posts.json"
    next unless File.exist? postFile

    posts = JSON.parse(File.open(postFile, 'r').read)

    posts.each { | value, key |
      count += 1
      file = blog + "/graphs/#{value}.json"

      break if count == 80000
      next unless File.exist? file
       
      data = File.open(file, 'r').read(20000)
      resultsMap[value] = [data.scan(reg).length, which]
    }
    postList << posts
    pathList << endpoint
    which += 1
  }

  puts Time.new - start
  resultsMap.sort_by{|k, v| v[0] }.reverse.slice(0,100).map { | name, count |
    postList[count[1]][name]  + [[pathList[count[1]],name].join(';')]
  }
end
