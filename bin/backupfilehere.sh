#!/bin/bash

fileWpath=${1}
fileName=$(basename -- $fileWpath)
fileNoExt="${fileName%.*}"
fileExt="${fileName##*.}"
 
/bin/cp "$1" "$1.bak-$(date +%Y%m%d-%H%M%S).$fileExt"

res=$?
if [[ $res != 0 ]] ; then
    yad --error --text="Failed $1 (not root?)"
fi
