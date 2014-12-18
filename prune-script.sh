#!/bin/sh

# This script looks for delisted blogs to move them aside
cd /raid/tumblr
[ -e site.stats ] && rm site.stats

for i in *.com; do
   exist=`curl -s -I $i | head -1 | tr '\r' ' '`
   echo "$i $exist" >> site.stats
done

## You can run this over the list
# cat site.stats | grep 404 | awk ' { print $1 } ' | xargs -I %% -n 1 mv %% lost
