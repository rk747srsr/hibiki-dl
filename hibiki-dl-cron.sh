#!/usr/bin/env bash

pid=$$
date=`date +%Y%m%d`
tmpdir=/tmp
vartmpdir=/var/tmp
outdir=$HOME/Downloads
omid=11276; omid=$(($omid - 2))
omidinfo='yonakamake20200329'
ver=1.1.3

usage() {
  echo "hibiki-dl-cron.sh($ver): HiBiKi Radio Station downloader"
  echo '  NOOPTION                downloads'
  echo '  -U                      cache updates'
  echo '  --id=<id> (-o outname)  download <id>'
  echo '  --set-id=<id>           download, set start <id>'
  echo '  -h                      help'
}
[ "$1" = '-h' ] && usage && exit 0

# options
[ ! -f $vartmpdir/hibiki_id ] && echo $omid >$vartmpdir/hibiki_id
[ "$1" = '-o' ] && shift
case $1 in
  -U)
  option_U=on
  ;;
  --id=[0-9]*)
  optarg_stop=on
  id=$1; id=${id#*=}; id=$(($id - 2))
  [[ `echo $* | grep '\-o'` ]] && name=$* && name=${name#*-o}
  ;;
  --set-id=[0-9]*)
  id=$1; id=${id#*=}; id=$(($id - 2))
  ;;
esac
[ ! $id ] && id=`cat $vartmpdir/hibiki_id`
# naming
[ ! "$name" ] && name='HIBIKI_'
name=${name/ /}

# downloads
[ ! option_U ] && echo "$$ [download] `date '+%m-%d %H:%M:%S'` start"
optqrg_skip=1
until [[ $optarg_skip -ge 5 ]]
do
  unset optarg_404
  while :
  do
    # get token
    m3u8=`curl -s -k -X GET -H X-Requested-With:XMLHttpRequest https://vcms-api.hibiki-radio.jp/api/v1/videos/play_check?video_id=$id | grep -o 'https.*\-1'`
    # exit
    [ ! $m3u8 ] && optarg_404=$(($optarg_404 + 1)) || unset optarg_404
    [[ $optarg_404 -ge 5 ]] && id=$(($id + 1)) && break
    # download
    if [[ ! $option_U && ! $optarg_404 ]]; then
      unset optarg_skip
      names=$name${date}_$(($id + 2))
      ffmpeg -n -i $m3u8 -loglevel quiet -acodec copy -vcodec copy $tmpdir/$names.ts
      if [ -f $tmpdir/$names.ts ]; then
        # tmp to out
        if [[ ! `ffmpeg -i $tmpdir/$names.ts 2>&1 | grep 'Video'` ]]; then
          echo "$$ $m3u8 -> $outdir/$names.m4a"
          ffmpeg -n -i $tmpdir/$names.ts -loglevel error -bsf:a aac_adtstoasc -acodec copy -vn $outdir/$names.m4a
        else
          echo "$$ $m3u8 -> $outdir/$names.ts"
          cp $tmpdir/$names.ts $outdir/
        fi
        [ -f $tmpdir/$names.ts ] && echo -n "$$ duration:" && ffmpeg -i $tmpdir/$names.* 2>&1 | grep -Po '(?<=Duration:).+?(?=,)'
        [ $optarg_stop ] && exit 0
      fi
    fi
    [[ -f $tmpdir/$names.ts || $option_U ]] && id=$(($id + 1))
    sleep 1
    names=$name
  done
  optarg_skip=$(($optarg_skip + 1))
  id=$(($id + 1))
done
[ ! $option_U ] && echo "$$ [download] `date '+%m-%d %H:%M:%S'` successful"
# cache update
[ ! $option_U ] && idsft=10 || idsft=30
echo $(($id - $idsft)) >$vartmpdir/hibiki_id

