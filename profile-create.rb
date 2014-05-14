require 'rubygems'
require 'set'
require 'bundler'
Bundler.require
$r = Redis.new
$size = [$r.hlen('users').to_i, 1].max

$trans = Redis.new

def user(who)
  return $id if who == $last
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

# the graph jsons are standard in.
# the data dir is argv[0]
$stdin.each_line do | file |
  entry = shouldparse? file.strip!
  next unless entry

  $start = Time.new unless $start

  $trans.multi if count % 40 == 0
  File.open(file, 'r') { | x | 
    reblog, likes = JSON.parse(x.read)
    
    reblog.values.each { | tuple |
      shouldAdd = true
      # If any of the reblogs have been seen in the digest, then don't do anything here.
      tuple.each { | who, post |
        ttl += 1
        shouldAdd = false if $r.sismember('digest', digest(who, post))
      }

      if shouldAdd
        tuple.each { | who, post |
          # Add this persons reblog unless we've parsed their reblog before
          $trans.sadd(user(who), entry)
        }
      end
    }

    #likes.each { | who |
    #  $trans.sadd(user(who), entry)
    #}
  }
  count += 1

  $trans.sadd('digest', entry)
  $trans.exec if (count % 40 == 0)

  puts "#{file} #{(ttl / (Time.new - $start)).to_i} #{ ttl }" if count % 12 == 0
end

# and one final exec
$trans.exec
