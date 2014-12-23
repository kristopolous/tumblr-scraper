require 'rubygems'
require 'rack'
require 'bundler'
$:.unshift File.dirname(__FILE__)
require 'profile-grep-smart'
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

def user(who)
  $id = $r.hget('users', who)

  if $id.nil?
    $id = [$size].pack('l')
    if $size < 16777216

      if $size < 65536

        $id = $id[0..1]

      else
        $id = $id[0..2]
      end

    end
    
    $r.hset('users', who, $id)
    $trans.hset('ruser', $id, who)

    $size += 1
  end

  $id
end
def digest(who, post)
  # Use 40 bits instead of 64
  # 32-bit user id + 40-bit post id = 9B
  "#{ [post.to_i].pack('q')[0..4] }#{ user( who ) }"
end

$depth = 27
def vote(what, amount)
  ix = 0
  who, postid = what.split('/')

  if amount < 0
    $r.zincrby('votes', amount, digest(who, postid)) 
    $r.sadd('hidden', digest(who, postid))
  end

  users = get_log(what)
  puts "#{what} #{users.length}"

  return if users.length == 0
  count = amount * Math.sqrt(Math.sqrt(Math.sqrt((1.000 / users.length))))
 
  idList = $r.hmget('users', users.shuffle[0..$depth])
  idList.each { | who |
    reblogs = $r.smembers(who)

    incr = count * Math.sqrt(Math.sqrt(1.0000/reblogs.length))
    reblogs.shuffle[0..$depth].each { | id |
      ix += 1
      $r.zincrby('votes', incr, id)
    }
  }
  puts (ix.to_f / ($depth * $depth).to_f)
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
      return entries[postid] if entries.has_key? postid
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

  def query(qstr)
    where, what = qstr.split('|')
    profile_grep(where,what)
  end

  def megaup(what)
    vote(what, 5.0)
  end

  def up(what)
    vote(what, 1.0)
  end

  def megadown(what)
    vote(what, -10.0)
  end

  def hide(what)
    who, postid = what.split('/')
    $r.sadd('hidden', digest(who, postid))
  end

  def down(what)
    vote(what, -1.0)
  end

  def relevant(count)
    count, start = count.split('|')
    start = start.to_i
    count = count.to_i
    
    puts "#{start} #{count}"

    map = []
    $r.zrevrange('votes', start, count).each { | x |
      map << to_image(x) unless $r.sismember('hidden', x)
    }
    last = count + start

    if (map.length < count) 
      $r.zrevrange('votes', last, count * 10).each { | x |
         map << to_image(x) unless $r.sismember('hidden', x) or map.length > count
      }
    end
    puts map.length
    map[0..count]
  end

  def random(count)
    $r.srandmember('digest', count).map { | x | 
      x = $r.srandmember('digest', 1).first while $r.sismember('hidden', x)
      to_image(x)
    }
  end

  def call(env)
    [200, {}, 
      [self.send(env['REQUEST_PATH'][1..-1],env['QUERY_STRING']).to_json]
    ]
  end
end

