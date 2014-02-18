require 'rubygems'
require 'bundler'
Bundler.require

$start = Time.new
Dir.chdir(ARGV[0])
startNodes = Dir["*.0"]

def parsefile(doc)
  {
    :reblog => doc.css('.reblog').map { | x |
      [
        #from
        x.css('.source_tumblelog').map { | y | y.inner_html }.first,
        #who
        x.css('.tumblelog').map { | y | y.inner_html }.first,
        #post
        x.css('.action').map { | y | y.attr('data-post-url').split('/').pop }.first.to_i
      ]
    },
    :like => doc.css('.like').map{ | x | x.css('a').last.inner_html }
  }
end

puts "#{startNodes.length} posts"
puts "time | left  | remaining "
count = 0

startNodes.each { | x |
  count += 1

  if count % 10 == 0
    duration = Time.new - $start
    ttl = (duration / (count.to_f / startNodes.length.to_f)).to_i
    togo = "%d:%02d" % [(ttl / 60).to_i, ttl % 60]
    lapsed = "%d:%02d" % [(duration / 60).to_i, (duration % 60).to_i]

    puts "#{lapsed} | #{togo} | #{startNodes.length - count}"
  end

  post, id = x.split('.')
  output = "#{post}.json"

  like = []
  reblog = {}
  todel = []

  Dir["#{post}*"].each { | page |
    next if page == output

    File.open(page, 'r') { | content |
      raw = content.read
      set = parsefile Nokogiri::HTML(raw, &:noblanks)
      set[:reblog].each { | row |
        from, who, post = row
        reblog[from] = [] unless reblog.has_key? from
        reblog[from] << [who, post]
      }
      like.concat(set[:like])
    } 
    todel << page
  }

  File.open(output, 'w') { | f |
    f << [reblog, like].to_json
  }

  ## Make sure that we don't remove the file until
  # after our intended output has been written
  todel.each { | file | File.unlink(file) }
}
