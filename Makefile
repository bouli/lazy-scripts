.PHONY: clean create

clean:
	sudo rm -f /usr/local/bin/bouli-sandbox
	sudo rm -f /usr/local/bin/bouli-garbage-collector
	sudo rm -f /usr/local/bin/ralph-afk
	sudo rm -f /usr/local/bin/push-loop
	sudo rm -f /usr/local/bin/ai-sbx
	sudo rm -f /usr/local/bin/ai-sbx-codex


	sudo rm -f /usr/local/bin/bouli-streaming-interval
	sudo rm -f /usr/local/bin/bouli-streaming-background
	sudo rm -f /usr/local/bin/bs
	sudo rm -f /usr/local/bin/bsi
	sudo rm -f /usr/local/bin/bss
	sudo rm -f /usr/local/bin/bsc
	sudo rm -f /usr/local/bin/bso
	zsh

create:
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/bouli-sandbox
	chmod +x $(PWD)/development/sandbox_launcher.sh
	sudo ln -s $(PWD)/development/clean_garbage_collector.sh /usr/local/bin/bouli-garbage-collector
	chmod +x $(PWD)/development/clean_garbage_collector.sh

	sudo ln -s $(PWD)/development/afk_ralph.sh /usr/local/bin/ralph-afk
	chmod +x $(PWD)/development/afk_ralph.sh

	sudo ln -s $(PWD)/development/push_loop.sh /usr/local/bin/push-loop
	chmod +x $(PWD)/development/push_loop.sh

	sudo ln -s $(PWD)/development/sbx_launcher.sh /usr/local/bin/ai-sbx
	chmod +x $(PWD)/development/sbx_launcher.sh

	sudo ln -s $(PWD)/development/sbx_codex.sh /usr/local/bin/ai-sbx-codex
	chmod +x $(PWD)/development/sbx_codex.sh


	sudo ln -s $(PWD)/streaming/interval.sh /usr/local/bin/bouli-streaming-interval
	chmod +x $(PWD)/streaming/interval.sh

	sudo ln -s $(PWD)/streaming/background.sh /usr/local/bin/bouli-streaming-background
	chmod +x $(PWD)/streaming/background.sh
	sudo ln -s $(PWD)/streaming/bs.py /usr/local/bin/bs
	chmod +x $(PWD)/streaming/bs.py
	sudo ln -s $(PWD)/streaming/bsi.sh /usr/local/bin/bsi
	chmod +x $(PWD)/streaming/bsi.sh
	sudo ln -s $(PWD)/streaming/bss.sh /usr/local/bin/bss
	chmod +x $(PWD)/streaming/bss.sh
	sudo ln -s $(PWD)/streaming/bsc.sh /usr/local/bin/bsc
	chmod +x $(PWD)/streaming/bsc.sh
	sudo ln -s $(PWD)/streaming/bso.sh /usr/local/bin/bso
	chmod +x $(PWD)/streaming/bso.sh
	zsh
