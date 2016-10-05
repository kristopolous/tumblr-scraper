# Introduction


I have a personal project where I'm trying to build a recommendation engine based on tumblr.  These are the tools I'm using to build it.

I don't have oodles of VC capital to throw at this problem and so this is designed to run on a regular consumer grade internet connection on somewhat modern hardware. The machine I use is an i5-3270 with 32GB of RAM and 8TB of SATA raid - my connection is a measely 3MB DSL.

Let's go over the tools:

  * tumblr-all-downloader - Gets the graphs, videos, and feeds of a blog in HTML
  * note-collapse - Ingests the HTML graphs from the first script into .json files and deletes the graphs.
  * log-digest - Ingests the posts from the first script and creates a json file representing the image content, does NOT delete the feeds.
  * top-fans - Finds related blogs based on the graphs of a scraped blog.
  * profile-create - Creates an inverse mapping of users -> blogs.

There's other tools here too ... I'll document them as time permits.

## Setup

In Oct 2016 this is what I had to do to get this running:
  
  $ sudo apt-get install ruby ruby-dev libmysqlclient-dev
  $ sudo gem install bundler
  $ bundle install

## tumblr-all-downloader

tumblr-all-downloader (the `scraper`) is for scraping tumblr blogs to get posts, notes, feeds and videos. The script is

 * re-entrent
 * and gets the first 1050 notes for each post (soon to be configurable)

There's a few optimizations dealing with unnecessary downloads.  It tries to be robust in terms of failed urls, network outages, and other types of conditions. Scrapers should be solid and trustworthy.

Usage is:

    $ ruby tumblr-all-downloader.rb some-user.tumblr.com /raid/some-destination

`/raid/some-destination/some-user.tumblr.com` will be created and then it will try to download things into it as quickly as possible.

### output 

The status output of the script is as follows:

    2782 265.99M 10:17 441K/18.5F http://blog.com/foo /raid/blog.com/bar
    (1)  (2)     (3)   (4)  (5)   (6)                 (7)

  1. Estimated number of items to download (presuming every post has a full set of notes)
  2. Amount of uncompressed data downloaded
  3. Run-time of the scrape
  4. Average uncompressed throughput
  5. Average number of files downloaded per second
  6. Current url being scraped
  7. The file it's being written to

When you are done you'll get the following:

    /raid/blog.tumblr.com
    \ _ graphs - a directory of the notes labelled postid.[0...N]
     |_ keys - access keys in order to get the raw notes feed (as opposed to the entire page)
     |_ logs - a directory of md5 checksummed files corresponding to the RSS feeds of image and video posts
     |_ badurl - a list of 40x urls to not attempt again
     |_ vids - a list of fully resolved video urls which can be used as follows:

     $ cat vids | xargs -n 1 mplayer -prefer-ipv4 -nocache -- 

     Or, I guess if you prefer,

     $ cat vids | xargs wget


> Note: The system *does not* download images.  It downloads logs which can be digested to output the image urls. (look at log-digest)

### suggested usage

Currently I manually curate the blogs to scrape.  I place them in a file I call sites and I run the following:

    $ shuf sites | xargs -n 1 -I %% ruby tumblr-all-downloader.rb %% /raid/tumblr

And then come back to it a few days later.

> Note: Sometimes the script deadlocks (2014 - 03 - 02). I don't like this either and I'm trying to figure out what the issue is.

## note-collapse

note-collapse will take a graph directory generated from the `scraper`, parse all the notes with nokogiri, and then write the following to `post-id.json` in the graphs directory:

    [
      {
        user-reblogged-from: [
          [ who-reblogged-it, post-id ],
          [ who-reblogged-it, post-id ],
          [ who-reblogged-it, post-id ],
        ],
        user-reblogged-from: [
          [ who-reblogged-it, post-id ],
          [ who-reblogged-it, post-id ],
          [ who-reblogged-it, post-id ],
        ]
      },
      [
        user-who-favorited,
        user-who-favorited,
        user-who-favorited,
      ],
      *last-id-scraped
    ]

After it successfully writes the json, the script will remove the source html data to conserve inodes and disk space.  When the .ini support is added this will be configurable.

However, all the useful data (for my purposes any way) is captured in the json files.

If there were more pages to capture (As in the number of notes captured weren't all of them), then the URL of what would have been the next page to capture is placed as the 3rd
item in the json.  If there is no 3rd item, it means that all the notes associated with the post at the time of the scrape are there.

### output

    40:19 | 63:33 | 7505 | 3209.33 MB
    (1)     (2)     (3)    (4)

 1. The time the script has run
 2. The estimated total time until the script is finished
 3. The number of posts to still digest
 4. The current total disk-space freed by the collapse (inode overhead not included)

For busier blogs, seeing multiple gigabytes freed by the collapse is *common*.

### suggested usage

The way I'm using this script is as follows:

    $ du -s /raid/tumblr/*/graphs \
       | sort -nr \
       | awk '{print $2}' \
       | xargs -n 1 -P 2 ruby note-collapse.rb

It's not the fastest thing on the planet, but it does work.

> Note: running `note-collapse` over a blog currently being scraped feels like a bad idea and is totally not supported.  `note-collapse` should be run carefully, on directories that aren't being processed by any other script here.

## top-fans

top-fans will take the collapsed notes from `note-collapse` and then compute the following:

  * Total number of reblogs per user
  * Total number of likes per user

When run over a blog, you can use this tool to discover similar content.

### output

Currently it outpus in very human-format ways - the top 25 in three columns:

  * reblogs + likes
  * likes
  * reblogs

With each numerically sorted.

### suggested use

Presuming we are trying to find blogs related to say, [http://retrodust.tumblr.com](http://retrodust.tumblr.com) we do the following:

		$ ruby tumblr-all-downloader.rb http://retrodust.tumblr.com/ .
		...
		Come back in about 3 - 4 hours.
		...
		$ ruby note-collapse.rb retrodust.tumblr.com
		...
		Probably another 5 minutes
		...
    $ find retrodust.tumblr.com/graphs/ -name \*.json | ./top-fans.rb 
    ...........
     total                           likes                          reblogs
     1628 retrodust                 1189 moonsykes                 1628 retrodust                
     1363 pixelated-entropy          732 fahrradkatze              1363 pixelated-entropy        
     1189 moonsykes                  335 slidinsideways             212 80sdoesitbetter          
      732 fahrradkatze               226 thecreamofhercrop          159 ashleyrunnels            
      335 slidinsideways             221 chipfuel                   125 constellationstar45      
      294 constellationstar45        212 starscream-and-hutch       125 timurmusabay             
      226 thecreamofhercrop          209 oracleofmefi               117 staticagenostalgia       
      221 chipfuel                   171 guyjaundice                 96 vivanlos80               
      215 starscream-and-hutch       169 constellationstar45         89 unkindheart              
      212 80sdoesitbetter            161 gentlepowerthings           88 trashback                
      209 oracleofmefi               156 monsieurlacombe             69 andreserm                
      171 guyjaundice                154 ivory                       68 bonytanks                
      165 gentlepowerthings          141 kirajuul                    65 peazy86                  
      163 ivory                      117 overleningrad               65 backtolife1991           
      162 peazy86                    114 simulacreant                64 madkid3                  
      159 ashleyrunnels              109 toreap                      63 mildviolence             
      156 monsieurlacombe            108 dafunkybot                  60 eight13                  
      154 toreap                     105 onwingslikeseagulls         59 partyandbullshitand      
      147 eight13                    105 gabrielverdon               50 astrogunpowergrid        
      144 kirajuul                   101 70years                     47 calledtobesons           
      134 simulacreant                96 peazy86                     47 iamcinema                
      129 overleningrad               87 eight13                     46 pepsunborja              
      126 retrostuff88                87 retrostuff88                45 anjunaalchemy            
      125 timurmusabay                77 metalzoic                   44 toreap                   
      120 vivanlos80                  76 iondrimba                   44 evocative-nightmare      
      119 dafunkybot                  75 summerstarkiss              42 vhs-80                   
      117 staticagenostalgia          68 altkomsu                    40 blvckbird-v35            
      106 onwingslikeseagulls         67 chosimbaone                 39 zapher                   
      105 gabrielverdon               67 zorrovolador                39 retrostuff88             
      102 70years                     64 jjpinbot                    38 supasteezin              
       89 unkindheart                 63 vadim-august                38 destination80s           
       88 trashback                   63 motionpixel                 37 great-atlas              
       86 summerstarkiss              63 reaganatbitburg             37 xx-xx9                   
       83 jjpinbot                    60 gatchaponblog               37 warners-retro-corner     
       82 soniccone                   58 somethingtedious            37 street-trash  

This doesn't take the volume of a users' post into consideration as a normalized magnitude but it helps try and find similar users


## log-digest

log-digest will take the md5-checksum named logfiles generated from the `scraper` and make a single `posts.json` file with all the posts.

To use it you do

    $ ruby log-digest.rb /raid/tumblr/site.tumblr.com/logs

It will then see if the `posts.json` digest file is newer then any of the logs. 

The format is as follows:

    { 
        postid : [ image0, image1, ..., imageN ],
        postid : [ image0, image1, ..., imageN ],
    }

### output

There's three(3) types of output:

    XXX /raid/blog/logs

Where XXX is one of the following:

  * ( number ) ( duration ) - the number of files digested to create the `posts.json` file + the time it took.
  * N/A - the `posts.json` is newer than all of the logs so was not created
  * "  >>> ???" - No logs were found in this directory ... it's worth investigating.

### suggeted usage

Currently I do this:

    $ find /raid/tumblr -name logs | xargs -n 1 ruby log-digest.rb

It's 

  * non-destructive, 
  * can be run while the other scripts are running
  * "relatively" swift
  * doesn't duplicate effort

So it's a fairly safe thing to run over the corpus at any time.

## profile-create

profile-create requires redis and `note-collapse` to be run over a scraped blog. It will open the note json digests created by `note-collapse` and then
create a user-based reverse-mapping of the posts in redis.

Say you have a post X with 20 reblogs R and 50 likes L.  A binary key representing each user who reblogged or liked the post will be
created in redis which points back to a binary representation of X - each user becomes a redis set.

This means that if you have scraped say, 500 or 1000 blogs and run this over that corpus, you can reconstruct a users' usage pattern; what they reblogged and liked.

### output

    /raid/t/blog.tumblr.com/graphs/123123231.json [number]
    (1)                                           (2)

Where:

 1. Last file digested  
 2. Cumulative rate of posts / second (higher is better)

### suggested usage

You need to feed in the jsons generated from `note-collapse` into `stdin` like so:

    $ find /raid/tumblr/ -name \*.json | grep graphs | ruby profile-create.rb

### schema

You **should not have existing data in the redis db prior to running this**.

There are 3 human readable keys:

 * users - a hash of usernames to ids
 * ruser - a hash of ids to usernames (reverse of users)
 * digest - a set of files previously parsed

The digest is referred to to make sure the script is re-entrent.  

The other keys are between 1 and 4 bytes and represent the id of the username (according to `users` hash) in LSB binary. There is an assumption that the user corpus will stay under 2^32 for your analysis.  Also, because user ids are 32 bit binaries, any key over 4 bytes long is safe to avoid collisions.

Each user has a set of "posts" which are the following binary format 

    [ 5 byte post id ][ 1 - 4 byte user id ]

The post id is taken by converting the postid to a 40 bit number and encoding it as LSB.  It will always be 40 bits (5 bytes).
The remainder of the post id (between 1 and 4 bytes) is the userid of the post.

This means that in ruby you could do the following:

    username = hget('ruser', postid[5..-1]) 
    postid = postid[0..4].unpack('Q')

Then using this, if you ran `log-digest` AND have scraped the username's blog you could go to `username.tumblr.com/logs/posts.json` and get the id `postid` and then reconstruct the actual post.

> Note: Although a good deal of effort was put into compacting the information sent to redis, multiple gigabytes of RAM (or redis-clustering) is highly recommended.

## profile-grep-smart

profile-grep-smart takes a stdin list of collapsed graphs (through `note-collapse`) and then reads over them
in a completely unparsed blob looking for the PCRE-style queries supplied in the ARGV parameters.  It records
the count number of them and then returns that, sorted, as the result.

### output

This is intended to be run as part of the web-stack on the `/query` endpoint. You can look into `api.rb` in
order to see an implementation of it.  Currently, it has `/raid/tumblr` as a hard-coded endpoint to search.

I'll make it more flexible if a bug is filed.

## asset-grab

asset-grab will pull down the assets that get logged from a tumblr site.  You should have already ran a 
`log-digest` over the list before running this.

### output

asset-grab doesn't actually download the content ... instead it outputs content to download to stdout. 
Ostensibly it's up to the user then to use xargs or any other kind of distributed downloader with a backoff
algorithm in order to actually retrieve the assets.  I recommend something with open-mpi over some cheap DO or 
linode machines.  Contact me for exapmles.

### Troubleshooting

#### Q: Hi. I was using your tool but now I get all these error pages from tumblr after a while.

**A:** Yes. Tumblr *will block you* after extensively using this tool - by IP address of course. The work-around is to use a proxy specified at the shell.  You can run things like rabbit or tinyproxy on a $5 vm or ec2 instance (they usually permit 1TB of traffic per month ... TB) and then do something like this:

    $ export http_proxy=http://stupid-tumblr.hax0rzrus.com:9666
    $ cat sites | xargs -n 1 -P 10 ...

I guess you could also use Tor, but then it will be sloow.  Rabbit is a good compression based proxy for tumblr in general - since for some unknown ungodly reason, being on the site drags a 2-300K/s downstream just idling (I haven't spent time looking into it, but it's just absurd).

##### lemma: chromium / chrome doesn't allow me to directly set the proxy and gives me some kind of grief.

**A:** That's right. Google's not your friend. You deserve better.

#### Q: The resolution on some of these assets kinda sucks. Can you magically fix this?

**A:** Of course. Tumblr stores higher resolution assets on almost everything.  The reason you don't see them is probably because of the stupid theme the person is using.  Replace the number at the end with 1280 instead of 500 and you are good.  The log-digest is smart enough to not fall for absurd things like this.

#### Q: I'm getting a "there's nothing to see here" with some weird full-screen gif playing in the background ... what is this? I want the content. Can you get that?

**A:** Yes. But first, have you been looking at dirty things on the internet again? Don't answer that.  That nuked blog had an RSS feed which links to assets which are probably still live.  The RSS feed 404's now but the web-based RSS readers have already scraped it.  This means that you can do something like:

    http://feedly.com/i/spotlight/http://nuked-blog.tumblr.com/rss

In your browser and blam, there you go.

Authors
-------

The downloader is based on an earlier work by the following:

* [Jamie Wilkinson](http://jamiedubs.com) ([@jamiew](https://github.com/jamiew))
* [James Scott-Brown](http://jamesscottbrown.com/) ([@jamesscottbrown](https://github.com/jamesscottbrown))
* [Chris McKenzie](http://9ol.es)


