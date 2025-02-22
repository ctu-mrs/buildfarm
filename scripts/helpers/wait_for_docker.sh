#!/bin/bash

for (( a=1 ; $a-180 ; a=$a+1 )) do

  has_error=$(docker info 2>&1 | grep ERROR | wc -l)

  if [ "$has_error" -eq "0" ]; then
    break
  fi

  echo "$0: waiting for docker to start"

  sleep 1

done

sleep 5

echo "$0: done"
