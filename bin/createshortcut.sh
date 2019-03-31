#!/bin/bash
# Creates Desktop shortcut to a file or Directory
# look for normal-file executable directory or .desktop file
# Spaces in File Names are a bitch

# remember %f from file manager
fileWpath="$1"

# need file name stripped of extension
fileName=$(basename -- $fileWpath)
fileNoExt="${fileName%.*}"
fileExt="${fileName##*.}"
filesPath=$( dirname "$fileWpath" )

# Where is our desktop os-agnostic

desktopDir=${XDG_DESKTOP_DIR:-$HOME/Desktop}
desktopFileName="${desktopDir}/${fileNoExt}.desktop"

# if file is a desktop file then just copy it
if [ ${fileExt} == "desktop" ]; then
	echo is a desktop file

# Why not just copy the file
	
	if [ ! -f "$desktopFileName" ]; then

		cp ${fileWpath} ${desktopDir}
		exit 2
	else
	
		yad --error --text="File exists ${desktopFileName}"
	
		exit 255
	fi
fi

# VARIABLE CHECKS

echo File Path ${fileWpath}
echo Path ${filesPath}
echo File name ${fileName}
echo FILE ${fileNoExt}
echo Extension ${fileExt}
echo Desktop Directory ${desktopDir}
echo Desktop File name${desktopFileName}
echo ---------------------------------------------

# Get file info

		#mimeType=`xdg-mime query filetype ${2}`
		#echo ${mimeType}
		
		#defaultApp=`xdg-mime query default ${mimeType}`
		#echo ${defaultApp}
	
appInfo=`/home/paul/bin/map-binary.sh "$fileWpath"`
echo _______________________________
echo  ${appInfo}

Exec=`echo $appInfo |awk 'NF > 1 {print $(NF - 3); }'`
Icon=`echo $appInfo |awk 'NF > 1 {print $(NF - 2); }'`
mimeType=`echo $appInfo |awk 'NF > 1 {print $(NF - 1); }'`

# Is file a standalone executible
# does it have a desktop file
echo ---------------------------------
echo
if [ -x "$fileWpath" ] && file "$fileWpath" | grep -q "GNU/Linux"
then
    echo "This is an executable Linux File"
#    sheBang="#!/usr/bin/env xdg-open\n"
    Exec=${fileWpath}
    Icon=${fileNoExt}
    fileWpath=""
elif [ -x "$fileWpath" ] && file "$fileWpath" | grep -q "shell script"
then
    echo "This is an executable Shell Script"
#    sheBang="#!/usr/bin/env xdg-open\n"
    Exec=${fileWpath}
    fileWpath=""
    #Icon=$
elif [ -x "$fileWpath" ]
then
    echo "This file is merely marked executable, but what type is a mystery"
else
    echo "This file isn't even marked as being executable"
fi
echo 
echo

#if echo  ${mimeType} | grep -q "application"; then
#    echo  is an application
#    Exec=${fileUri}
#    fileUri=""
#fi

echo MIME ${mimeType}
# These are the variables for the base desktop file

echo Exec ${Exec}
echo Icon ${Icon}

#defaultApp=`/home/paul/bin/map-binary.sh $file`
#echo Open with ${defaultApp}

# Create and edit .desktop file 

if [ ! -f "$desktopFileName" ]; then
echo ${desktopFileName}
touch ${desktopFileName}
	echo -e "${sheBang}[Desktop Entry]\nVersion=1.0\nName=${fileNoExt}\nIcon=${Icon}\nExec="${Exec}  ${fileWpath}"\nPath=$filesPath\nTerminal=false\nType=Application\n" > "${desktopFileName}"

	/usr/bin/lxshortcut -i ${desktopFileName}


else
	 yad --error --text="File exists ${desktopFileName}"
	exit 255
fi


exit 0
