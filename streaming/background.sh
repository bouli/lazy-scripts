	mkdir -p ~/scripts/streaming/wrk
	mkdir -p ~/scripts/streaming/public
	rm -f ~/scripts/streaming/wrk/*
	cp ~/scripts/streaming/inputs/background/*.wav ~/scripts/streaming/wrk
	printf "file '%s'\n" ~/scripts/streaming/wrk/*.wav > ~/scripts/streaming/wrk/to_merge.txt
	rm -f ~/scripts/streaming/public/background.wav
	ffmpeg -f concat -safe 0 -i ~/scripts/streaming/wrk/to_merge.txt -c copy ~/scripts/streaming/public/background.wav
