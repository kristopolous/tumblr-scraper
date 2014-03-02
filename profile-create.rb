require 'rubygems'
require 'set'
require 'bundler'
Bundler.require
$r = Redis.new

$datadir = ARGV[0]
$start = Time.new
$digest = Set.new
$sync_counter = 0
$usermap = {}


def check_sync(force = false)
  $sync_counter += 1

  if $sync_counter == 2000 or force
    puts "<sync>"
    save_digest
=begin    
    $usermap.each { | user, what | 
      next if user.nil?
      next if user.length == 0

      userfile = "#{$datadir}/#{user}"

      if File.exists? userfile
        File.open(userfile, "r") { | x | 
          userdata = JSON.parse(x.read)
          userdata[0] = Set.new(userdata[0])
          userdata[1] = Set.new(userdata[1])
        }
      end
      
      userdata = [
        userdata[0].merge(Set.new(what[:reblog])).to_a,
        userdata[1].merge(Set.new(what[:like])).to_a
      ]

      File.open(userfile, 'w') { | x | 
        x << userdata.to_json
      }

      user_init(user, true)
    }
=end
    $sync_counter = 0
  end
end

def add_reblog(who, what)
  $r.sadd("u:#{who}", what)
  #$usermap[who][:reblog] << what
  check_sync
end

def add_favorite(who, what)
  $r.sadd("u:#{who}", what)
  #$usermap[who][:like] << what
  check_sync
end

def load_digest
  File.open("#{$datadir}/.digest", "r") { | x |
    x.each_line do | line |
      $digest << line.strip
    end
  }
end

def save_digest
  File.open("#{$datadir}/.digest", "w") { | file |
    file.write($digest.to_a.join("\n"))
  }
end

def shouldparse? path
  parts = path.split('/')
  post = parts.last
  site = (parts[-3]).split('.').first
  post = post.split('.').first

  entry = [site, post].join('/')

  if $digest.include? entry
    puts "Skip"
    return false 
  end

  entry
end


s = Set.new

load_digest
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
  puts post

  $digest << post
end
sleep(10000)
