mkdir -p ~/scripts/streaming/wrk
mkdir -p ~/scripts/streaming/public
rm -f ~/scripts/streaming/wrk/*
cp ~/scripts/streaming/inputs/interval/*.mp4 ~/scripts/streaming/wrk
ffmpeg -i ~/scripts/streaming/wrk/video.mp4 -vf reverse ~/scripts/streaming/wrk/reverse.mp4
printf "file '%s'\n" ~/scripts/streaming/wrk/*.mp4 > ~/scripts/streaming/wrk/to_merge.txt
rm -f ~/scripts/streaming/public/interval.mp4
ffmpeg -f concat -safe 0 -i ~/scripts/streaming/wrk/to_merge.txt -c copy ~/scripts/streaming/public/interval.mp4
cp ~/scripts/streaming/inputs/interval/video.txt ~/scripts/streaming/public/interval.txt
