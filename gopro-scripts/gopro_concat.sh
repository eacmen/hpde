#!/bin/bash

VIDEO_IDS=$(ls *.MP4 | cut -c 5-8 | sort -u)
FFMPEG="/usr/local/bin/ffmpeg-4.0.2-64bit-static/ffmpeg"

for id in $VIDEO_IDS; do
	FILES=$(ls G???$id.MP4)
	for f in $FILES; do echo "file '$f'" >> $id.filelist.txt; done
	$FFMPEG -f concat -i $id.filelist.txt -c copy $id.mp4 &
done


for job in `jobs -p`
do
echo $job
    wait $job || let "FAIL+=1"
done

echo $FAIL

if [ "$FAIL" == "0" ];
then
echo "YAY!"
else
echo "FAIL! ($FAIL)"
fi

