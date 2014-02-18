## tumblr-all-downloader

tumblr-all-downloader is for scraping tumblr blogs to get images, notes, feeds, videos, and everything else. The script is

 * re-entrent
 * and gets the first 550 notes for each post

There's a few optimizations dealing with unnecessary downloads.  It tries to be robust in terms of failed urls, network outages, and other types of conditions. Scrapers should be solid and trustworthy.

Usage is:

    $ ruby tumblr-all-downloader.rb some-user.tumblr.com /raid/some-destination

`/raid/some-destination/some-user.tumblr.com` will be created and then it will try to download things into it as quickly as possible.

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


## note-collapse

There's an **optional** tool called note-collapse.rb, which will take a graph directory generated from the downloader, parse all the notes, and then write the following to post-id.json:

    [/*reblog*/
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
      ]
    ]

After it successfully writes, it will remove the source html data.  There's a few reasons for this:

 * The graph is easily ready for any type of further analysis
 * It is 1/11th the number of files and about 1/12th the file size.

In fact, as you run it you'll see output like this:

    40:19 | 63:33 | 7505 | 3209.33 MB
    (1)     (2)     (3)    (4)

 1. The time the script has run
 2. The estimated total time until the script is finished
 3. The number of posts to still digest
 4. The current total disk-space freed by the collapse (inode overhead not included)

For busier blogs, seeing multiple gigabytes freed by the collapse is *common*.

The way I'm using this script is as follows:

    $ du -s /raid/tumblr/*/graphs \
       | sort -nr \
       | awk '{print $2}' \
       | xargs -n 1 -P 2 ruby note-collapse.rb

It's not the fastest thing on the planet, but it does work.

Authors
-------

The downloader is based on an earlier work by Jamie Wilkinson. 

* [Jamie Wilkinson](http://jamiedubs.com) ([@jamiew](https://github.com/jamiew))
* [James Scott-Brown](http://jamesscottbrown.com/) ([@jamesscottbrown](https://github.com/jamesscottbrown))
* [Chris McKenzie](http://9ol.es)


