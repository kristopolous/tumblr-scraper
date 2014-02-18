require 'rubygems'
require 'bundler'
Bundler.require

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

startNodes.each { | x |
  post, id = x.split('.')
  output = "#{post}.json"

  like = []
  reblog = {}

  Dir["#{post}.*"].each { | page |
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
    File.unlink(page)
  }

  File.open(output, 'w') { | f |
    f << [reblog, like].to_json
  }
    
}
