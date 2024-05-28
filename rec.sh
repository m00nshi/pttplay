#!/usr/bin/env bash

HW_VOLUME_PLAYBACK_LEVEL=14
HW_VOLUME_RECORD_LEVEL=35
#POLL_INTERVAL=0.2

ADEVICE="$1"
HID_DEVICE="$2"
#MEDIA_FILE="$3"

set +e
trap "kill 0" EXIT

aplay -q -D "$ADEVICE" -t wav /dev/zero        # test and fail early if can't access audio h/w
amixer -q -D "$ADEVICE" set Speaker "$HW_VOLUME_PLAYBACK_LEVEL"
amixer -q -D "$ADEVICE" set Speaker on
amixer -q -D "$ADEVICE" set Mic "$HW_VOLUME_RECORD_LEVEL"
amixer -q -D "$ADEVICE" set 'Auto Gain Control' on
amixer -q -D "$ADEVICE" set Mic unmute


gethidreport() {
    hidapitester -q --open-path "$HID_DEVICE" -t 0 --open -l 3 --read-input-report 0
}

pipe_path="/tmp/whisper_pipe"
mkfifo "$pipe_path"

cleanup() {
	rm -f "$pipe_path"
}
trap cleanup EXIT


# states : 
# none - 00 02 00
# receive - 00 00 00
# transmit - 00 02 04

prev_state=" 00 02 00"

while true; do
	state=$(gethidreport)
#	echo "$state" >&2
	if [ "$state" == " 00 00 00" ] && [ "$prev_state" != " 00 00 00" ]; then
	# when state changes from none to receive - start recording
		echo "Start recording.." >&2
     		arecord -D "$ADEVICE" -f S16_LE -t wav -r 44100 -c 1 > "$pipe_path" &
		rec_pid=$!
		prev_state="$state"
	elif [ "$state" != " 00 00 00" ] && [ "$prev_state" == " 00 00 00" ]; then
	# when state changes from receive to none - terminate recording
		echo "Stop recording.." >&2
		kill "$rec_pid"
		kill -2 "$rec_pid"
		wait "$rec_pid" 2>/dev/null
		prev_state="$state"
	fi
	# when state changes from none to transmit
	# ignore
	# when state changes from receive to transmit
	# same as from receive to none - terminate recording 
	# when state changes from transmit to none 
	# ignore
	# when state changes from transmit to receive
	# same as fron none to receive - start recording
	sleep 0.3
done

#-----------------------------------------------
#
#
#trap "kill 0" EXIT
#
#while true; do
#
#if [ "$(gethidreport)" != " 00 00 00" ]
#then
#    echo "Waiting for carrier..." >&2
#    sleep $POLL_INTERVAL
#fi
#
#while [ "$(gethidreport)" != " 00 00 00" ]; do sleep $POLL_INTERVAL; done
#
#echo "Recording..." >&2
#
#set +e                                      # make sure failures don't prevent killing the arecord process
#
#if [ "$MEDIA_FILE" = "-" ]; then
#    arecord -D "$ADEVICE" -f S16_LE -t wav -r 44100 -c 1 -N &
#else
#    arecord -D "$ADEVICE" -f S16_LE -t wav -r 44100 -c 1 -N "$MEDIA_FILE" &
#fi
#
#while [ "$(gethidreport)" = " 00 00 00" ]; do
#    sleep $POLL_INTERVAL
#    while [ "$(gethidreport)" = " 00 00 00" ]; do
#        sleep $POLL_INTERVAL
#        while [ "$(gethidreport)" = " 00 00 00" ]; do
#            sleep $POLL_INTERVAL
#        done
#    done
#done
#done
