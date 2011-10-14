#!/bin/bash
# TODO: This needs a *Serious* overhall.
# Key problems:
#	bash dependent!
#	runs the get_iplayer scripts too many times
#	need to catch when rtmpdump breaks, and restart it
#	Use built in pvr?

# check not already running
/usr/bin/pgrep "$0" >/dev/null && {
    echo "Error: $0 already running."
    exit 1
}
# check for internet connection
[[ "$(/usr/bin/wicd-cli -yd)$(/usr/bin/wicd-cli -zd)" ]] || {
    echo "Error: No internet connection" 1>&2
    exit 1
}

# check for iplayer dir - don't allow root for my setup
[ "$iplayer_dir" ] || iplayer_dir="/home/$USER/Videos/iplayer/"
[ -d "$iplayer_dir" ] || {
    echo "Error: iplayer directory does not exist." 1>&2
    echo "	     export valid 'iplayer_dir' or create" 1>&2
    echo "       $iplayer_dir" 1>&2
    exit 1
}

case "$(/bin/basename $0)" in

    ("get_iplayer.series")

	# define temporary files
	series_file=~/.get_iplayer/series.ls
	streams_file=~/.get_iplayer/streams.ls
	# all the programs from iplayer in temp series file
	/usr/local/bin/get_iplayer --nopurge --series |
	    /bin/sed -n 's:  \+([0-9]\+).*$::p' | /usr/bin/uniq >$series_file
	# number of series streams downloaded set to 0
	number_streams=0

	for x in $(/usr/bin/find "$iplayer_dir" -maxdepth 1 -type d)
	do

	    stream_name="$(/bin/basename $x | /bin/sed "y:_: :")"
	    # all the series varients in temp stream file
	    /bin/grep "$stream_name" <$series_file >$streams_file
	    
	    # number of series downloaded set to 0
	    number_series=0

	    # for all the series sub dirs
	    for y in $(/usr/bin/find "$x" -type d -name 'Series_*')
	    do
		series_name="$stream_name: $(/bin/basename $y | /bin/sed "y:_: :")"
		if [[ "$(/bin/grep "$series_name" <$streams_file)" ]]
		then
		    #echo "Downloading new programs for $series_name"
		    (
		    cd "$y"
		    /usr/local/bin/get_iplayer --nopurge -g "^$series_name"
		    cd -
		    ) >/dev/null &
		    (( number_series+=1 ))
		fi
	    done

	    if (( $(wc -l <$streams_file) > $number_series ))
	    then
		#echo "Downloading new programs for $stream_name"
		(
		cd "$x"
		/usr/local/bin/get_iplayer --nopurge -g "^$stream_name"
		cd -
		) &>/dev/null &
		(( number_series+=1 ))
	    fi
	    (( number_streams+=number_series ))

	done

	echo "Programs for $number_streams series are available."
	echo "Fetching new ones now..."

	;;

    ("get_iplayer.films")

	cd $iplayer_dir >/dev/null
	/usr/local/bin/get_iplayer --nopurge -l --category=Films \
	    --modes=flashhd,flashvhigh "$@"
	cd - >/dev/null

	;;

    ("get_iplayer.live")

	/usr/local/bin/get_iplayer --nopurge --type=livetv,liveradio \
	    --stream "$@" --player="mplayer -cache 128 -" 

	;;

esac
