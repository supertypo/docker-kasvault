#!/bin/sh
docker run --rm -it -p 3000:3000 supertypo/kasvault:unstable "$@"
