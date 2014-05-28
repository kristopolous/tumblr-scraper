require 'rubygems'
require 'bundler'
Bundler.require

$start = Time.new
Dir.chdir(ARGV[0])
startNodes = Dir["*.0"]

def parsefile(doc)
  {
    :reblog => doc.css('.reblog').map { | x |
      begin
        [
          #from
          x.css('.source_tumblelog').map { | y | y.inner_html }.first,
          #who
          x.css('.tumblelog').map { | y | y.inner_html }.first,
          #post
          x.css('.action').map { | y | y.attr('data-post-url').split('/').pop }.first.to_i
        ]
      rescue
        puts '.'
        nil
      end
    },
    :like => doc.css('.like').map{ | x | 
      set = x.css('a')
      return '' if set.last.nil?
      set.last.inner_html
    },
    :original => doc.css('.original_post').map { | x |
      begin
        [
          #from
          x.css('.source_tumblelog').map { | y | y.inner_html }.first,
          #who
          x.css('.tumblelog').map { | y | y.inner_html }.first,
          #post
          x.css('.action').map { | y | y.attr('data-post-url').split('/').pop }.first.to_i
        ]
      rescue
        puts '.'
        nil
      end
    }
  }
end

puts "#{startNodes.length} posts"
puts " time | total | remain | +space"
count = 0
space_in = 0
space_out = 0

startNodes.each { | x |
  count += 1

  if count % 5 == 0
    sleep(0.1)
    duration = Time.new - $start
    ttl = (duration / (count.to_f / startNodes.length.to_f)).to_i
    togo = "%02d:%02d" % [(ttl / 60).to_i, ttl % 60]
    lapsed = "%02d:%02d" % [(duration / 60).to_i, (duration % 60).to_i]
    saved = "%2.02f MB" % [(space_in - space_out).to_f / (1024 * 1024).to_f]
    remain = "%6d" % [startNodes.length - count]

    puts "#{lapsed} | #{togo} | #{remain} | #{saved}"
    puts "-----\n#{ARGV[0]}" if count % 150 == 0
  end

  post, id = x.split('.')
  output = "#{post}.json"

  like = []
  reblog = {}
  original = false
  todel = []

  lastscrape = false
  postlist = Dir["#{post}*"]
  postlist.each { | page |
    next if page == output

    File.open(page, 'r') { | content |
      raw = content.read

      if (postlist.length - 1) == page.split('.').last.to_i
        raw.scan(/'(\/notes\/[^\']*)',/) { | x | 
          lastscrape = x 
        }
      end

      space_in += raw.length
      set = parsefile Nokogiri::HTML(raw, &:noblanks)

# The "original" is the earliest reference point.
      original = set[:original] 
      original = set[:reblog].last if original.length == 0

      set[:reblog].each { | row |
        next if row.nil?
        from, who, post = row
        reblog[from] = [] unless reblog.has_key? from
        reblog[from] << [who, post]
      } unless set[:reblog].nil?

      like.concat(set[:like]) unless set[:like].nil?
    } 
    todel << page
  }

  # Only collapse if there is data
  if like.length > 0
    payload = [reblog, like, original]
    payload << lastscrape if lastscrape

    payload = payload.to_json

    space_out += payload.length
    File.open(output, 'w') { | f |
      f << payload
    }

    ## Make sure that we don't remove the file until
    # after our intended output has been written
    todel.each { | file | File.unlink(file) }
  end
}
