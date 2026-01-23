.PHONY: clean create

clean:
	sudo rm -f /usr/local/bin/bouli-sandbox
	sudo rm -f /usr/local/bin/bouli-garbage-collector
	zsh

create:
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/bouli-sandbox
	chmod +x ./development/sandbox_launcher.sh
	sudo ln -s $(PWD)/development/clean_garbage_collector.sh /usr/local/bin/bouli-garbage-collector
	chmod +x ./development/clean_garbage_collector.sh
	zsh
