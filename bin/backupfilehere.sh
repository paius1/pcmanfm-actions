#!/bin/bash

for FILE in "$@"; do

    fileWpath=${FILE}
    fileName=$(basename -- $fileWpath)
    fileNoExt="${fileName%.*}"
    fileExt="${fileName##*.}"

    /bin/cp "$FILE" "${FILE}-$(date +%Y%m%d-%H%M%S).BAK.$fileExt"
    res=$?

    if [[ $res != 0 ]] ; then
     yad --error --text="Failed to copy $FILE (not root?)"
    fi
done

exit 0
