#!/usr/bin/env bash

date=`date +%Y%m%d`
tmpdir=/tmp
omid=11276; omid=$(($omid - 2))
omidinfo='yonakamake20200329_last'
ver=1.2.5

usage() {
  echo "hibiki-player.sh($ver): HiBiKi Radio Station player"
  echo '  NOOPTION       play'
  echo '  -U             cache updates'
  echo '  --id=<id>      play <id>'
  echo '  --set-id=<id>  play, set start <id>'
  echo '  -h             help'
}
[ "$1" = '-h' ] && usage && exit 0

# options
#[ ! -f $tmpdir/hibiki_id ] && echo $omid >$tmpdir/hibiki_id
[ -f /var/radio/spool/hibiki_id ] && cp /var/radio/spool/hibiki_id $tmpdir/hibiki_id || echo $omid >$tmpdir/hibiki_id
case $1 in
  -U)
  optarg_U=on
  ;;
  --id=[0-9]*)
  optarg_stop=on
  id=$1; id=${id#*=}; id=$(($id - 2))
  ;;
  --set-id=[0-9]*)
  id=$1; id=${id#*=}; id=$(($id - 2))
  ;;
esac
[ ! $id ] && id=`cat $tmpdir/hibiki_id`

# play
while :
do
  # get token
  m3u8=`curl -s -k -X GET -H X-Requested-With:XMLHttpRequest https://vcms-api.hibiki-radio.jp/api/v1/videos/play_check?video_id=$id | grep -o 'https.*\-1'`
  # exit
  [ ! $m3u8 ] && optarg_404=$(($optarg_404 + 1)) || unset optarg_404
  [[ $optarg_404 -ge 5 ]] && id=$(($id - 3)) && break
  # play
  if [[ ! $optarg_U && ! $optarg_404 ]]; then
    echo $m3u8 | grep -Po '(?<=video_id=)[0-9]*'
    (ffmpeg -i $m3u8 -loglevel error -acodec copy -vcodec copy -f mpegts pipe:1 | mplayer -really-quiet -) 2>/dev/null &
    echo 'download:r  next:anykey reload:z exit:q'
    # download
    killplay() {
      kill `ps x | grep -v grep | grep mplayer.*\-$ | awk '{print $1}'` 2>/dev/null
    }
    while read -s -n 1 key
    do
      case $key in
        r|R)
        killplay
        read -p '-o ' name; names=${name:=HIBIKI_}${date}_$(($id + 2))
        ffmpeg -i $m3u8 -loglevel quiet -acodec copy -vcodec copy $tmpdir/$names.ts
        [ $? != 0 ] && m3u8=`curl -s -k -X GET -H X-Requested-With:XMLHttpRequest https://vcms-api.hibiki-radio.jp/api/v1/videos/play_check?video_id=$id | grep -o 'https.*\-1'` && ffmpeg -i $m3u8 -loglevel error -acodec copy -vcodec copy $tmpdir/$names.ts
        if [[ ! `ffmpeg -i $tmpdir/$names.ts 2>&1 | grep 'Video'` ]]; then
          ffmpeg -i $tmpdir/$names.ts -loglevel error -bsf:a aac_adtstoasc -acodec copy -vn $names.m4a 2>/dev/null
          rm $tmpdir/$names.ts
        else
          mv $tmpdir/$names.ts ./
        fi
        echo $m3u8
        echo 'successful'
        break
        ;;
        q|Q)
        killplay
        exit 0
        ;;
        z|Z)
        killplay
        option_z=on
        break
        ;;
        *)
        killplay
        break
        ;;
      esac
    done
    echo
    [ $optarg_stop ] && exit 0
  fi
  [ ! $option_z ] && id=$(($id + 1)) || unset option_z
done
# cache update
echo $(($id - 1)) >$tmpdir/hibiki_id

