# This handles backslashes but not quote marks.

first_word()
{
    read first rest
    echo "${first}"
}

file=${1}
echo Output from map-binary.sh

mimeType=`mimetype "$file" | awk '{print $NF}'`

desktopIcon=`cat /usr/share/mime/generic-icons|grep ${mimeType} |awk -F: '{print $2}'`

desktopFile=`xdg-mime query default ${mimeType}`
# So what if there is no default application????
if [  -z "$desktopFile" ]; then
	desktopFile=NULL.desktop
	echo "No Program"
fi
# So what if there is no icon????

if [ -z $desktopIcon ]; then
	desktopIcon=applications-other
fi
#echo $file
#echo $mimeType
#echo $desktopFile
#exit 0


#-------------------------------------------------------------
# map a .desktop file to a binary
#desktop_file_to_binary()
#{
    search="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    desktop="`basename "$desktopFile"`"
    IFS=:
    for dir in $search; do
        unset IFS
        [ "$dir" ] && [ -d "$dir/applications" ] || [ -d "$dir/applnk" ] || continue
        # Check if desktop file contains -
        if [ "${desktop#*-}" != "$desktop" ]; then
            vendor=${desktop%-*}
            app=${desktop#*-}
            if [ -r $dir/applications/$vendor/$app ]; then
                file_path=$dir/applications/$vendor/$app
            elif [ -r $dir/applnk/$vendor/$app ]; then
                file_path=$dir/applnk/$vendor/$app
            fi
        fi
        if test -z "$file_path" ; then
            for indir in "$dir"/applications/ "$dir"/applications/*/ "$dir"/applnk/ "$dir"/applnk/*/; do
                file="$indir/$desktop"
                if [ -r "$file" ]; then
                    file_path=$file
                    break
                fi
            done
        fi
        if [ -r "$file_path" ]; then
            # Remove any arguments (%F, %f, %U, %u, etc.).
            command="`grep -E "^Exec(\[[^]=]*])?=" "$file_path" | cut -d= -f 2- | first_word`"
            command="`which "$command"`"
            readlink -f "$command"
        fi
    done
echo $desktopIcon
echo $mimeType
echo $desktopFile

exit 0
