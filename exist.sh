#!/bin/sh

# This script looks for delisted blogs to move them aside

while read site; do
   exist=`curl -s -I $site | head -1 | tr '\r' ' '`
   echo "$site $exist"
done

