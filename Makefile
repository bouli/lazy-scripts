.PHONY: clean create

clean:
	sudo rm -f /usr/local/bin/bouli-sandbox
	sudo rm -f /usr/local/bin/bouli-garbage-collector
	sudo rm -f /usr/local/bin/bouli-streaming-interval
	sudo rm -f /usr/local/bin/bouli-streaming-background
	sudo rm -f /usr/local/bin/bs
	zsh

create:
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/bouli-sandbox
	chmod +x $(PWD)/development/sandbox_launcher.sh
	sudo ln -s $(PWD)/development/clean_garbage_collector.sh /usr/local/bin/bouli-garbage-collector
	chmod +x $(PWD)/development/clean_garbage_collector.sh
	sudo ln -s $(PWD)/streaming/interval.sh /usr/local/bin/bouli-streaming-interval
	chmod +x $(PWD)/streaming/interval.sh
	sudo ln -s $(PWD)/streaming/background.sh /usr/local/bin/bouli-streaming-background
	chmod +x $(PWD)/streaming/background.sh
	sudo ln -s $(PWD)/streaming/bs.py /usr/local/bin/bs
	chmod +x $(PWD)/streaming/bs.py
	zsh
