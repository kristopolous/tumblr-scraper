require 'rubygems'
require 'set'
require 'bundler'
Bundler.require
$r = Redis.new

$datadir = ARGV[0]
$start = Time.new

def user(who)
  id = $r.hget('u', who)

  if id.nil?
    id = $r.hlen('u')
    $r.hset('u', who, id)
  end

  id
end

def add_reblog(who, what)
  $r.sadd(user(who), what)
end

def add_favorite(who, what)
  $r.sadd(user(who), what)
end

def shouldparse? path
  puts path
  parts = path.split('/')
  post = parts.last

  site = (parts[-3]).split('.').first
  userid = [user(site).to_i].pack('l')

  # Use 48 bits instead of 64
  post = [post.split('.').first.to_i].pack('q').unpack('SSS').pack('SSS')

  # 32-bit user id + 48-bit post id = 10B
  entry = [userid, post].join('')

  if $r.sismember('digest', entry) 
    puts "Skip"
    return false 
  end

  entry
end


# the log files are standard in.
# the data dir is argv[0]
$stdin.each_line do | file |
  file.strip!
  post = shouldparse? file
  next unless post
  File.open(file, 'r') { | x | 
    entries = JSON.parse(x.read)
    
    # reblogs
    entries[0].values.each { | tuple |
      tuple.each { | x |
        add_reblog(x[0], post)
      }
    }

    # favorites
    entries[1].each { | who |
      add_favorite who, post
    }
  }

  $r.sadd('digest', post)
end
sleep(10000)
