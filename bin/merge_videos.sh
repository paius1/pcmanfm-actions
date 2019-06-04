#!/usr/bin/env bash
#
# Script to merge video files using mencoder
#

# pcmanfm sends %codes in file names
# file=$(printf "%b\n" "${@//%/\\x}")

vids="$@"
number=$#

IFS=' ' read -r -a videos <<< $vids
rm /tmp/concat.list

# info for the file given  
  tmpFilename="${videos[1]}"
  fileName=$(echo "${tmpFilename##*/}")
# remove %whatever
  fileName=$(printf "%b\n" "${fileName//%/\\x}")
  path=$(dirname "$tmpFilename")
  path=$(printf "%b\n" "${path//%/\\x}")
  path=$(echo $path|sed 's/file:\/\///g')
#  path=$(printf '%q' "$path")

# Here so I can check what pcmanfm sends to script
#(for file in "${videos[@]}"; do echo $file; done) | yad --text-info --width=800 --height=300  

# Allow user to change saved file name and path
  dialog=$(yad --center --window-icon=gtk-no \
      --window-icon=gtk-save \
	  --borders=15 \
	  --title="Save Merged File As..." \
	  --text-align=center \
	  --text="\nSave Joined File as\n" \
	  --form \
	  --field="Save to Filename:" "merged-${fileName}" \
	  --field="Save in Direcotry::MDIR" "${path}")
ret=$?
  if [ "$ret" = "1" ]; then
	exit 
  fi

  path=$(echo $dialog | cut -d'|' -f 2)
  path=$(printf '%q' "$path")
  fileName=$(echo $dialog | cut -d'|' -f 1)
  output="${path}/${fileName// /_}"

    yad --center --window-icon=gtk-yes \
	    --window-icon=gtk-yes \
	    --borders=20 \
	    --title="Saving File to  "$fileName"" \
	    --text-align=center \
	    --text="Output file<b>\n${fileName}\n\nto Dirctory\n${path}</b>\n" \
	    --button=gtk-yes:0 --button=gtk-no:1
ret=$?
  if [ "$ret" = "1" ]; then
	exit 
  fi


for file in ."${videos[@]}"; do

  # strip file://
  firstStep=$(echo $file | sed 's/file:\/\///g')
  echo 1st $firstStep
  # change "%20' etc
  secondStep=$(printf "%b\n" "${firstStep//%/\\x}")
  echo 2nd $secondStep
# don't know why a random . shows up but oh well
  secondStep=$(echo $secondStep | sed  's/^\.//')  
###############################################################  
  # Get duration and fps
duration=( $(ffmpeg -i "$secondStep" 2>&1 | sed -n "s/.* Duration: \([^,]*\), start: .*/\1/p") )
fps=( $(ffmpeg -i "$secondStep" 2>&1 | sed -n "s/.*, \(.*\) tbr.*/\1/p") )
hours=( $(echo $duration | cut -d":" -f1) )
minutes=( $(echo $duration | cut -d":" -f2) )
seconds=( $(echo $duration | cut -d":" -f3) )

# Get the integer part with cut
frames=( $(echo "($hours*3600+$minutes*60+$seconds)*$fps" | bc | cut -d"." -f1) )
totalFrames=$((totalFrams + frames))
echo ""$secondStep" has $frames frames, now converting" >> /tmp/trans.log
###############################################################  
  # escape special charachters like space and []
  thirdStep=$(printf '%q' "$secondStep")
  echo 3rd $thirdStep
  
  echo file "$thirdStep" >> /tmp/concat.list
  #echo "file $thirdStep" | sed -e 's/ /\\ /g' -e 's/\\ / /1' >> /tmp/concat.list
  done
# don't know why a random . shows up but oh well
#  sed -i 's/\.\//\//g;s/=//g' /tmp/concat.list 
echo Total Frames = $totalFrames >> /tmp/trans.log
#exit 0
xterm -geometry 110x20+100+100 -e "ffmpeg -hide_banner -f concat -safe 0 -i /tmp/concat.list -c copy $output; read -p 'Press the any key'"

rm /tmp/concat.list

exit 0
