#!/bin/sh

useragent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.3"

#download a file from the web in 32 megabyte chunks, to allow for interruption and subsequent resuming of (download of) large files
#(note: requires correct support from the http server)

if [ "${1}" = "" ]; then
echo "Download URL required for Argv1"
exit
fi
if [ "${2}" = "" ]; then
echo "Output filename required for Argv2"
exit
fi

outputName="$(basename ${2})"

chunkSizeInBytes="33554432"
chunkIndex="0"
startByte="0"
if [ ! -d ".${outputName}-parts" ]; then
mkdir ".${outputName}-parts"
fi
cd ".${outputName}-parts"
while true; do
if [ ! -f "${chunkIndex}.complete-part" ]; then

	if [ -f "${chunkIndex}.part" ]; then
		rm "${chunkIndex}.part"
	fi

echo "${startByte}"
	#wget --start-pos ${startByte} --warc-max-size=${chunkSizeInBytes} "${1}" -O "${chunkIndex}.part"
	
	#curl --user-agent "insert user agent" -L -C ${startByte} -r ${startByte}-$(expr ${startByte} + 32768) "${1}" -o "${chunkIndex}.part"
	#wget "${1}" -c --header="Range: bytes=${startByte}-$(expr ${startByte} + 32768)" -O "${chunkIndex}.part"

	curl --fail --user-agent "${useragent}" -e robots=off -X GET -L -H "Range: bytes=${startByte}-$(expr ${startByte} + ${chunkSizeInBytes} - 1)" "${1}" -o "${chunkIndex}.part"
	curlResult="$?"
	if [ "${curlResult}" != 0 ]; then
		if [ -f "${chunkIndex}.part" ]; then
			rm "${chunkIndex}.part"
		fi
		curl --fail --user-agent "${useragent}" -e robots=off -X GET -L -H "Range: bytes=${startByte}-" "${1}" -o "${chunkIndex}.part"
		curlResult="$?"
		if [ "${curlResult}" != 0 ]; then
			echo "Got error ${curlResult} downloading chunk ${chunkIndex}."
			echo "This may be because you are offline or the server doesn't support byte serving."
			echo "Cleaning up and exiting."
			if [ -f "${chunkIndex}.part" ]; then
				rm "${chunkIndex}.part"
			fi
			exit
		else
			mv "${chunkIndex}.part" "${chunkIndex}.complete-part"

			echo "Assembling file..."
			for file in $(find . -maxdepth 1 -name "*.complete-part" -type f | sort -k2); do
				cat ${file} >> "${outputName}"
				rm "${file}"
			done
			mv "${outputName}" "../${outputName}"
			cd ..
			rmdir ".${outputName}-parts"
			echo "Success!"
			exit
		fi
	else
		#if it downloaded successfully and is smaller in size than the chunk index, then it is the last chunk already, so clear up
		checkthebytes="$(du -b ${chunkIndex}.part | cut -f1)"
		if [ ${checkthebytes} -lt ${chunkSizeInBytes} ] && [ ${checkthebytes} != 0 ]; then
			mv "${chunkIndex}.part" "${chunkIndex}.complete-part"

			echo "Assembling file..."
			for file in $(find . -maxdepth 1 -name "*.complete-part" -type f | sort -k2); do
				cat ${file} >> "${outputName}"
				rm "${file}"
			done
			mv "${outputName}" "../${outputName}"
			cd ..
			rmdir ".${outputName}-parts"
			echo "Success!"
			exit
		elif [ "${checkthebytes}" = "0" ]; then
			rm "${chunkIndex}.part"
			cd ..
			rmdir ".${outputName}-parts"
			echo "The first chunk is zero bytes"
			echo "This may be because you are offline or the server doesn't support byte serving."
			echo "Cleaning up and exiting."
			exit
		else
			mv "${chunkIndex}.part" "${chunkIndex}.complete-part"
		fi

	fi
	sleep 1
fi

startByte="$(expr ${startByte} + ${chunkSizeInBytes})"
chunkIndex="$(expr "${chunkIndex}" + 1)"
done