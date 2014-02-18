So there's a tool here called tumblr-all-downloader  It's like the Jamie Wilkinson implementation but it's

 * re-entrent
 * you get post details
 * you get the first 550 notes for each post
 * it downloads video urls

And there's a few optimizations dealing with unnecessary downloads.  It also tries to be far more robust in terms of failed urls, network outages, and other types of conditions.

There's also a tool called note-collapse.rb, which will take a graph directory generated from the downloader, parse all the notes, and then output the following:

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

in the post-id.json.  Then it will remove all the html data.  There's a few reasons for this:

 * The graph is easily ready for any type of further analysis
 * It is 1/11th the number of files and about 1/12th the file size.

In fact, as you run it you'll see output like this:

    26:29 | 66:12 |  12310 | 1404.07 MB

    (1)    (2)      (3)     (4)


 1. The time the script has run
 2. The estimated total time until the script is finished
 3. The number of posts to still digest
 4. The current total disk-space freed by the collapse (inode overhead not included) 

The way I'm using this script is as follows:

    $ du -s /raid/tumblr/*/graphs \
       | sort -nr \
       | awk '{print $2}' \
       | xargs -n 1 -P 2 ruby note-collapse.rb

It's not the fastest thing on the planet, but it does work.

Authors
-------

* [Jamie Wilkinson](http://jamiedubs.com) ([@jamiew](https://github.com/jamiew))
* [James Scott-Brown](http://jamesscottbrown.com/) ([@jamesscottbrown](https://github.com/jamesscottbrown))
* [Chris McKenzie](http://9ol.es)


