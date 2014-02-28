require 'rubygems'
require 'bundler'
Bundler.require

$start = Time.new

Dir.chdir(ARGV[0])
logList = Dir.glob("*") 

def parsefile(doc)
  Hash[
    (doc/'post').map { | post |
      [
        post['url'].to_s.split('/').pop, 
        (post/'photo-url').select { | x | 
          x['max-width'].to_i == 1280 
        }.map { | x | x.content.to_s  }
      ]
    }
  ]
end

hash = {}
logList.each { | file |
    next if file == 'badurl' or file == 'posts.json'

    File.open(file, 'r') { | content |
      hash.merge! parsefile Nokogiri::XML.parse(content)
    }
}

File.open('posts.json', 'w') { | f |
  f << hash.to_json
}

puts "#{Time.new - $start} #{ARGV[0]}"
