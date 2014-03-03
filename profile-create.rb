require 'rubygems'
require 'set'
require 'bundler'
Bundler.require
$r = Redis.new
$size = $r.hlen('users').to_i

$trans = Redis.new

def user(who)
  id = $r.hget('users', who)

  if id.nil?
    id = [$size].pack('l').rstrip
    
    $r.hset('users', who, id)
    $size += 1

    # do a reverse lookup
    $trans.hset('ruser', id, who)
  end

  id
end

def digest(who, post)
  "#{ [post.to_i].pack('q')[0..4] }#{ user( who ) }"
end

def shouldparse? path
  parts = path.split('/')

  # Use 40 bits instead of 64
  # 32-bit user id + 40-bit post id = 9B
  entry = digest( parts[-3].split('.').first, parts.last.split('.').first )

  if $r.sismember('digest', entry) 
    printf '.' if rand < 0.1
    return false 
  end 

  entry
end


$start = false
count = 0
freq = 0

# the log files are standard in.
# the data dir is argv[0]
$stdin.each_line do | file |
  entry = shouldparse? file.strip!
  next unless entry

  $start = Time.new unless $start
  
  $trans.multi if count % 30 == 0
  File.open(file, 'r') { | x | 
    reblog, likes = JSON.parse(x.read)
    
    reblog.values.each { | tuple |
      tuple.each { | who, post |
        freq += 1
        # Add this persons reblog to the digest so we don't double-parse it
        $trans.sadd(user(who), entry) unless $r.sismember('digest', digest(who, post))
      }
    }

    #likes.each { | who |
    #  $trans.sadd(user(who), entry)
    #}
  }
  count += 1

  $trans.sadd('digest', entry)
  $trans.exec if (count % 30 == 0)

  puts "#{file} #{count / (Time.new - $start)} #{ freq / count }"
end
