#!/usr/bin/env bash
# Normalize audio stream in video file so explosions don't cover up dialogue
#
# For PcManFm custom actions using ffmpeg and yad
#
# Many thanks to Rupert Plumridge www.prupert.co.uk for the code to create a progress bar
#  &
# https://gist.github.com/leesei
# for bash uri parser 
#  &
# from https://forum.videohelp.com/threads/366765-FFMPEG-Compand-settings-suggestions-please "tugshank"
# af "aformat=channel_layouts=stereo, ..." important for mono audio
#
# pcmanfm custom action (~/.local/share/file-manager/actions)
#	[Desktop Entry]
#	Type=Action
#	NoDisplay= false
#	Name[en_US]=Normalize Audio
#	Tooltip=Normalize Audio
#	ToolbarLabel[en_US]=Normalize Audio
#	Icon=video
#	TryExec=yad
#	Profiles=profile-video;
#	Mimetypes=video/*;
#
#	[X-Action-Profile profile-video]
#
#	MimeTypes=video/*;
#	Exec=Normalize_Audio.sh %f
#	Name[en_US]=Normalize Audio
#
# ffmpeg filters
#	Make music with both quiet and loud passages suitable 
# 	for listening to in a noisy environment:
# 	compand=".3|.3:1|1:-90/-60|-60/-40|-40/-30|-20/-20:6:0:-90:0.2"
#
#	audio with whisper and explosion parts
#	compand="0|0:1|1:-90/-900|-70/-70|-30/-9|0/-3:6:0:0:0 "
#
#	Unsure where I found these
#	compand='0.0,1 6:-70,-43,-20 -6 -90 0.1'
#	compand='.13|.13:.35|.35:-70/-35|-35/-20|-20/-15|-15/-15:6:-3.01:-90:0.2' 
#

# sample for testing comment out for entire file
#  time=(-t 120)
#  seek=( -ss 00:25:00)

# test for arguments
  [ $# -eq 0 ] && { echo -e " Usage: $0 /some/video/file\n"; exit 1 > /dev/null 2>&1; }

# Check for yad
  command -v yad >/dev/null 2>&1 || { echo -e  "\n     YAD NOT FOUND     \n" | xmessage -center -file -; exit 1; }

# Might as well check for ffmpeg
  command -v ffmpeg >/dev/null 2>&1 || { echo -e  "\n     FFMPEG NOT FOUND     \n" | yad --center --text-info; exit 1; }

# pcmanfm sends %codes in file names
  video=$(printf "%b\n" "${1//%/\\x}")

# info for the file
  path=$(dirname "$video")
  fileName=$(basename  "$video")
  inputFile=$fileName

# info for the video
  ffProbe=$(ffprobe -hide_banner -show_format "$video" 2>&1)
  audioCodec=$(echo $ffProbe |sed -n "s/.* Audio: \([^,]*\),\? .*/\1/p" | cut -d' ' -f1)
  nb_streams=$(echo $ffProbe |sed -n "s/.* nb_streams=\([0-9]*\) .*/\1/p")
  audioStreams=$(ffprobe -i "${video}" -show_format -hide_banner 2>&1 | egrep -m "$nb_streams" 'Audio:') 
  nb_audioStreams=$(echo $audioStreams | grep -o "Audio:" | wc -l)
  fps=$(echo $ffProbe | sed -n "s/.*, \(.*\) tbr.*/\1/p")
  duration=$(echo $ffProbe |sed -n "s/.* Duration: \([^,]*\), start: .*/\1/p")
	hours=$(echo $duration | cut -d":" -f1)
	minutes=$(echo $duration | cut -d":" -f2)
	seconds=$(echo $duration | cut -d":" -f3)
  frames=$(echo "($hours*3600+$minutes*60+$seconds)*$fps" | bc | cut -d"." -f1)
  
# yad dialog if only 1 audio stream
  dialogArray=(yad --center --window-icon=multimedia-volume-control --borders=20 --title="Normalizing Audio in ${fileName}" --text-align=center --text="\nNormalizing Audio in\n<b>${fileName}</b>\n"  --form --field="Save to:" "${fileName}" --field="Save in:MDIR" "${path}" --field="":LBL "" --field="\t\tChose Compressor/Expander":LBL "" --field="Pick One":CB 'Explosions & Whispers!Dialogue!Test CompAnd')
  
# yad dialog for start time & duration
#  if [ -z $time ]; then
#	dialogArray=("${dialogArray[@]}" 
#  fi
  
# nb_audioStreams >2 so add audio stream chooser to yad dialog
  if [ $nb_audioStreams -gt 1 ]; then
	  for ((field=1;field<$nb_audioStreams+1;field++)); do
		audioCB="${audioCB}"$(echo $audioStreams|cut -d'#' -f$(( field + 1 ))| cut -d':' -f2)"!"
	  done
	  audioCB="${audioCB}"ALL
 	  dialogArray=("${dialogArray[@]}" --field="":LBL "" --field="\t\tChoose Audio Stream":LBL "" --field="Pick One":CB "$audioCB")
  fi

# Allow user to change saved file name and path, choose compand preset and audio stream(s)
  dialog=$("${dialogArray[@]}")
	ret=$?
	  if [ "$ret" = "1" ]; then
		exit 
	  fi

  path=$(echo $dialog | cut -d'|' -f 2)
  fileName=$(echo $dialog | cut -d'|' -f 1)
  compressorExpander=$(echo $dialog | cut -d'|' -f 5)

# create map for audio
  if [ $nb_audioStreams -gt 1 ]; then
	stream=$(echo $dialog | rev | cut -d'|' -f2 | rev)
	map=()
	if [ "$stream" = "ALL" ]; then
	  map=(-map 0:0)
	  for ((index=1;index<$nb_streams;index++)); do
		map=("${map[@]}" -map 0:${index})
	  done
	else
	  audioStream=$(echo $stream | head -c 1)
	  map=(-map 0:0 -map 0:${audioStream})
	fi
  fi

# set compand
  if [ "$compressorExpander" = "Explosions" ]; then
	compAnd="0 0:1 1:-90/-900 -70/-70 -30/-9 0/-3:6:0:0:0"
  elif [ "$compressorExpander" = "Dialogue" ]; then
	compAnd=".3|.3:1|1:-90/-60|-60/-40|-40/-30|-20/-20:6:0:-90:0.2"
  else
	compAnd=".13|.13:.35|.35:-70/-35|-35/-20|-20/-15|-15/-15:6:-3.01:-90:0.2"
  fi

# replace spaces with '_' to avoid overwriting existing file?
  output="${path}/${fileName// /_}"

# Check if we have already reencoded the file since ffmpeg normally checks and requires y/N

	# for files on the GNOME Virtual file system
	# use bash uri parser 
	# from https://gist.github.com/leesei
	  function uri_parser() {
	    # uri capture
	    uri="$@"
	
	    # safe escaping
	    uri="${uri//\`/%60}"
	    uri="${uri//\"/%22}"
	
	    # top level parsing
	    pattern='^(([a-z]{3,5})://)?((([^:\/]+)(:([^@\/]*))?@)?([^:\/?]+)(:([0-9]+))?)(\/[^?]*)?(\?[^#]*)?(#.*)?$'
	    [[ "$uri" =~ $pattern ]] || return 1;
	
	    # component extraction
	    uri_schema=${BASH_REMATCH[2]}
	    uri_user=${BASH_REMATCH[5]}
	    uri_host=${BASH_REMATCH[8]}
	    uri_path=${BASH_REMATCH[11]}
	
	    # return success
	    return 0
	  }

# create valid GVfs file path or keep unix path
  uri_parser "$output" && FILE=$XDG_RUNTIME_DIR/gvfs/$uri_schema:host=$uri_host,user=$uri_user"$uri_path" || FILE=$output

  if [ -f "$FILE" ]; then
    yad --center --window-icon=gtk-no \
	    --window-icon=gtk-no \
	    --borders=20 \
	    --title="File Exists "$fileName"" \
	    --text-align=center \
	    --text="\n<b>${fileName}\n\nExists ... Replace?</b>\n" \
	    --button=gtk-yes:1 --button=gtk-no:0

	  if [ $? == "0" ]; then
        exit 0
	  else
	    rm "$FILE"
	  fi
  fi
  
echo conversion of "$video" started on `date "+%m/%d/%y %l:%M:%S %p"` > /tmp/trans.log
echo  path $path  >> /tmp/trans.log
echo  inputFile $inputFile  >> /tmp/trans.log
echo  fileName $fileName  >> /tmp/trans.log
echo  audioCodec $audioCodec  >> /tmp/trans.log
echo  audioStreams $audioStreams  >> /tmp/trans.log
echo  nb_audioStreams  $nb_audioStreams  >> /tmp/trans.log
echo  compressorExpander  $compressorExpander  >> /tmp/trans.log
echo  compAnd  $compAnd  >> /tmp/trans.log
echo  map ${map[@]}  >> /tmp/trans.log

# Many thanks to Rupert Plumridge www.prupert.co.uk for the code to create a progress bar
###################################################
# function to do the actual encoding
  trans() {
	ffmpeg -n  -hide_banner "${seek[@]}" "${time[@]}" -i "$video" -strict experimental -af "aformat=channel_layouts=stereo, compand=${compAnd}" "${map[@]}" -c:v copy -c:a "$audioCodec" "$output"
#
# or uncomment next 3 lines to watch encoding in terminal
#uri_parser "$video" && IN=$XDG_RUNTIME_DIR/gvfs/$uri_schema:host=$uri_host,user=$uri_user"$uri_path" || IN=$video
#uri_parser "$output" && OUT=$XDG_RUNTIME_DIR/gvfs/$uri_schema:host=$uri_host,user=$uri_user"$uri_path" || OUT=$output
#xterm -geometry 111x15+100+100 -e bash --init-file <(echo ffmpeg -n  -hide_banner -i "$IN" "${time[@]}" -strict experimental -af \"aformat=channel_layouts=stereo, compand=${compAnd}\" "${map[@]}" -c:v copy -c:a "$audioCodec" "$OUT" 2>&1 || : &&   read -n 1 -s -r -p 'Press any key to continue')
#
# you can also tail -f /tmp/ffmpeg.log
#
  }

# function to output remaining time and percent done
  progress() {
  sleep 4
  #some shenanigans due to the way ffmpeg uses carriage returns
  cat -v /tmp/ffmpeg.log | tr '^M' '\n' > /tmp/ffmpeg1.log

  #calculate percentage progress based on frames
  cframe=$(tac /tmp/ffmpeg1.log | grep -m 1 frame= | awk '{print $1}' | cut -c 7-)
  if [ "$cframe" = "" ]; then
	cframe=$(tac /tmp/ffmpeg1.log | grep -m 1 frame= | awk '{print $2}')
  else
	cframe=$cframe
  fi
  percent=$((100 * cframe / frames))

  #calculate time left
  fps=$(tac /tmp/ffmpeg1.log | grep -m 1 frame= | awk '{print $3}')
  if [[ "$fps" = "q="* ]]; then
	fps=$(tac /tmp/ffmpeg1.log | grep -m 1 frame= | awk '{print $2}')
  fi
  if [[ "$fps" = "fps="* ]]; then
	fps=$(echo $fps | awk -F'=' '{print $2}')
  else
	fps=$fps
  fi

  total=$( echo "$frames + $cframe + $percent + $fps" | bc   )
  total=${total%.*}

  #simple check to ensure all values are numbers
  if [ $total -eq $total 2> /dev/null ]; then
	#all ok continue
	if [ "$fps" = "0" ]; then
		echo "$percent" 
		echo "# Remaining ? to finish the job"
	else
		remaining=$(echo "$frames - $cframe" | bc)
		seconds=$(echo "$remaining / $fps" | bc )
		h=$(echo "$seconds / 3600" | bc )
		m=$(echo "( $seconds / 60 ) % 60" | bc )
		s=$(echo "$seconds % 60" | bc )
	  # format time to completion
		etc=''
		if [ "$h" -ne 0 ]; then
		etc="${h}h "
		fi
		if [ "$m" -ne 0  ]; then
		etc="${etc}${m}m "
		fi
		etc="${etc}${s}s"
		echo $percent
		echo "# ${percent}% done ...~${etc} to finish the job"
	fi
else
	echo $percent
	echo "# Error, one of the values wasn't a number"
fi
}

# call the conversion and fork it
  trans &>> /tmp/ffmpeg.log &

# get the PID of the conversion
  pid=$(pidof ffmpeg | sort | cut -d' ' -f1)
  echo pid ffmpeg $pid >> /tmp/trans.log

#############################

# Create progress bar
  ( while [ -e /proc/$pid ]; do progress; done )|
  yad --center \
	--width=400 \
	--height=50 \
	--borders=20 \
	--window-icon=gtk-save \
	--text-align=center \
	--title="Normalizing Audio" \
	--progress \
	--text="\nNormalizing Audio $stream in\n<b>$inputFile</b>\n\n$compressorExpander\n\nSaving in\n<b>$path</b>\nto\n<b>$fileName</b>\n" \
	--button="Cancel":1 \
	--auto-close 
  ret=$?

echo ffmpeg stopped on `date "+%m/%d/%y %l:%M:%S %p"` >> /tmp/trans.log

  if [ "$ret" = "1" ]; then
  	killall ffmpeg
# uncomment after debugging
#	rm /tmp/ffmpeg1.log
#	rm /tmp/ffmpeg.log
	exit 
  fi
 
# Check for errors
  errorCheck=$(tac /tmp/ffmpeg1.log | head -n 1 | egrep "error |Invalid |No |failed ")

  if [ -z "${errorCheck}" ]; then

# Success
  yad --center \
	  --window-icon=gtk-apply \
	  --borders=10 \
	  --height=200 \
	  --title="Normalizing Complete" \
	  --text-align=center \
	  --text="\nFile Name\n\n<b>${inputFile}</b>\n\nHas been sucessfully normalized to\n\n<b>${path}</b>\n as \n<b>${fileName}</b>\n" \
	  --button=gtk-ok:0
  # clear logs for debugging could just remove them
    echo > /tmp/ffmpeg1.log
    echo > /tmp/ffmpeg.log 
  else
# Errors encounterd
  yad --center \
	  --window-icon=gtk-dialog-error \
	  --borders=20 \
	  --title="Normalizing Failed" \
	  --text-align=center \
	  --text="\nffmpeg encounterd an error with\n\n<b>${fileName}</b>\n\nnormalized to\n\n<b>${fileName}\n in ${path}\nCheck /tmp/ffmpeg1.log </b>" \
	  --button=gtk-ok:0
  fi

exit 0
