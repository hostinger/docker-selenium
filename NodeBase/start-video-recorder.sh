#!/usr/bin/env bash

VIDEO_SIZE="${SE_SCREEN_WIDTH}""x""${SE_SCREEN_HEIGHT}"
DISPLAY_CONTAINER_NAME=${DISPLAY_CONTAINER_NAME}
DISPLAY_NUM=${DISPLAY_NUM}
FILE_NAME=${FILE_NAME}
FRAME_RATE=${FRAME_RATE:-$SE_FRAME_RATE}
CODEC=${CODEC:-$SE_CODEC}
PRESET=${PRESET:-$SE_PRESET}

return_code=1
max_attempts=50
attempts=0
echo 'Checking if the display is open...'
until [ $return_code -eq 0 -o $attempts -eq $max_attempts ]; do
	xset -display :${DISPLAY_NUM} b off > /dev/null 2>&1
	return_code=$?
	if [ $return_code -ne 0 ]; then
		echo 'Waiting before next display check...'
		sleep 0.5
	fi
	attempts=$((attempts+1))
done

recording_started="false"
last_session_id=""
video_file_name=""
while true;
do
	session_id=$(curl -s --request GET 'http://localhost:5555/status' | jq -r '.[]?.node?.slots | .[0]?.session?.sessionId')
	echo $session_id
	if [ $session_id != "null" -a $session_id != "" ] && [ $recording_started = "false" ];
	then
		echo 'Starting to record video'
		video_file_name="/tmp/$session_id.mp4"
		ffmpeg -nostdin -y -f x11grab -video_size ${VIDEO_SIZE} -r ${FRAME_RATE} -i ${DISPLAY_CONTAINER_NAME}:${DISPLAY_NUM}.0 -codec:v ${CODEC} ${PRESET} -pix_fmt yuv420p $video_file_name &
		last_session_id=$session_id
		recording_started="true"
		echo 'Video recording started'
	elif [ $session_id = "null" -o $session_id = "" ] && [ $recording_started = "true" ];
	then
		echo 'Stopping to record video'
		pkill --signal INT ffmpeg
		full_log_name="/tmp/$last_session_id:${POD_NAME}.log"
		mv ${LOG_FILE_NAME} $full_log_name
		export LAST_SESSION_ID=$last_session_id
		export FULL_LOG_NAME=$full_log_name
		export VIDEO_FILE_NAME=$video_file_name
		if [ ${UPLOAD_TO_S3} = "true" ];
		then
			./opt/bin/start-s3-uploader.sh &
		else
			echo 'Uploading to s3 disabled'
		fi
		recording_started="false"
		echo 'Video recording stopped'
	elif [ $recording_started = "true" ];
	then
		echo 'Video recording in progress'
	else
		echo 'No session in progress'
	fi
	sleep 1
done