require 'rubygems'
require 'set'
require 'bundler'
Bundler.require
$r = Redis.new
$size = $r.hlen('users').to_i

$trans = Redis.new

def user(who)
  return $id if who == $last

  $id = $r.hget('users', who)

  if $id.nil?
    id = [$size].pack('l').rstrip
    
    $r.hset('users', who, id)
    $size += 1

    # do a reverse lookup
    $trans.hset('ruser', id, who)
  end
  $last = who

  $id
end

def digest(who, post)
  # Use 40 bits instead of 64
  # 32-bit user id + 40-bit post id = 9B
  "#{ [post.to_i].pack('q')[0..4] }#{ user( who ) }"
end

def shouldparse? path
  parts = path.split('/')

  entry = digest( parts[-3].split('.').first, parts.last.split('.').first )

  return false if $r.sismember('digest', entry) 

  entry
end


$start = false
count = 0
ttl = 0

# the log files are standard in.
# the data dir is argv[0]
$stdin.each_line do | file |
  entry = shouldparse? file.strip!
  next unless entry

  $start = Time.new unless $start
  
  $trans.multi if count % 40 == 0
  File.open(file, 'r') { | x | 
    reblog, likes = JSON.parse(x.read)
    
    reblog.values.each { | tuple |
      tuple.each { | who, post |
        ttl += 1
        # Add this persons reblog unless we've parsed their reblog before
        $trans.sadd(user(who), entry) unless $r.sismember('digest', digest(who, post))
      }
    }

    #likes.each { | who |
    #  $trans.sadd(user(who), entry)
    #}
  }
  count += 1

  $trans.sadd('digest', entry)
  $trans.exec if (count % 40 == 0)

  puts "#{file} #{count / (Time.new - $start)} #{ ttl }" if count % 10 == 0
end

# and one final exec
$trans.exec
