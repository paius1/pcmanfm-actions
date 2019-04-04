#!/bin/bash
# Original from 
# https://github.com/madebits/linux-pcmanfm-actions
# changed backup pattern to maintain pcmanfm mimetype recognition and
# look for system dialog program
    options="xmessage xdialog zenity yad"
 
    for i in $options
    do
 	  command -v  $i >/dev/null && dialog=$i || echo "$i Not Found in \$PATH"
    done

# Backup File(s)
for FILE in "$@"; do
    fileWpath=${FILE}
    fileName=$(basename -- $fileWpath)
    fileNoExt="${fileName%.*}"
    fileExt="${fileName##*.}"

    /bin/cp "$FILE" "${FILE}-$(date +%Y%m%d-%H%M%S).BAK.$fileExt"
    results=$?
  # Copy Successful ?
    if [[ $results != 0 ]] ; then
        case $dialog in
          xdialog) echo "I don't know what to do with xdialog"
          ;;
          xmessage) { echo -e  "\n     Failed to backup $FILE (not root?)     \n" | xmessage -center -file -; }
          ;;
          zenity|yad) $dialog --center --error --text="Failed to copy $FILE (not root?)"
          ;;
          *) xterm -hold -e echo -e "\n      Failed to copy $FILE"
          ;;
        esac
    fi
done

exit 0
