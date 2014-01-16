So there's three tools here, that were based of an original Jamie Wilkinson implementation

 * tumblr-photo-downloader.rb downloads image
   * post details
   * the first 50 notes for each post
   * the image itself

 * tumblr-flash-downloader.rb is the same as the above but no images.

 * tumblr-video-downloader.rb follows video posts through and finds their eventual mp4 or flv and then concatenates them into a vids log file in the format

   [blog] [url]

If a blog goes offline, the resources remain up.  This means that you can do a (flash|videos)-downloader to get the links to the content and then use the photo downloader at a later date.

License
-------

Source code released under an [MIT license](http://en.wikipedia.org/wiki/MIT_License)

Pull requests welcome.


Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


Authors
-------

* [Jamie Wilkinson](http://jamiedubs.com) ([@jamiew](https://github.com/jamiew))
* [James Scott-Brown](http://jamesscottbrown.com/) ([@jamesscottbrown](https://github.com/jamesscottbrown))


