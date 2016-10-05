#!/bin/sh
# 
# This is a simple wrapper around the top-fans ruby
# script to make it less cumbersome to use
#
find $1 -name \*.json | ./top-fans.rb
