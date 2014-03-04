require 'rubygems'
require 'rack'
require 'bundler'
Bundler.require
$r = Redis.new

def get_log what
  who, postid = what.split('/')
  postgraph = "/raid/tumblr/#{who}.tumblr.com/graphs/#{postid}.json"
  if File.exists? postgraph
    File.open(postgraph, 'r') { | x |
      entries = JSON.parse(x.read)
      return (entries[0].values.map { | tuple | tuple.map { | who, what | who } }).flatten
    }
  end
end

def vote(what, amount)
  idList = $r.hmget('users', get_log(what)).shuffle[0..7]
  idList.each { | who |
    reblogs = $r.smembers(who).shuffle[0..7]
    reblogs.each { | id |
      $r.zincrby('votes', amount, id)
    }
  }
end

def to_image(what)
  entry = decode_entry(what) 
  [
    entry,
    get_content(entry)
  ]
end

def get_content what
  who, postid = what.split('/')
  postlog = "/raid/tumblr/#{who}.tumblr.com/logs/posts.json"
  if File.exists? postlog
    File.open(postlog, 'r') { | x |
      entries = JSON.parse(x.read)
      return entries[postid][0].shuffle.first if entries.has_key? postid
    }
  end
end

def decode_entry what  
  return [
    $r.hget('ruser', what[5..-1]),
    "#{what[0..4]}\000\000\000".unpack('Q')
  ].join('/')
end

class Api
  def initialize(app, options={})
  end

  def up(what)
    vote(what, 1)
  end

  def down(what)
    vote(what, -1)
  end

  def relevant(count)
    $r.zrevrange('votes', 0, count).map { | x |
      to_image(x)
    }
  end

  def random(count)
    $r.srandmember('digest', count).map { | x | 
      to_image(x)
    }
  end

  def call(env)
    [200, {}, 
      self.send(env['REQUEST_PATH'][1..-1],env['QUERY_STRING']).to_json
    ]
  end
end

