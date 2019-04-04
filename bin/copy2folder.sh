#!/bin/bash
# Original from
# https://github.com/madebits/linux-pcmanfm-actions

folder=$(yad --file-selection --directory --title="Copy To Folder")
if [[ $folder ]]; then
	# cp -r $@ "$folder"
	for file in "$@"
	do
	    cp -r "$file" "$folder"
	done
fi

exit 0
