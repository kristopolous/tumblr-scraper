#!/bin/sh

# This script looks for delisted blogs and has a cache

touch ~/exist.delisted.cache
while read site; do
   if [ `grep -c $site ~/exist.delisted.cache` = "0" ]; then
     exist=`curl -s -I $site | head -1 | tr '\r' ' '`
     if [ `echo $exist | grep -c 404` = "1" ]; then 
       echo "$site" >> ~/exist.delisted.cache
     else
       echo $site
     fi
   fi
done

