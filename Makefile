.PHONY: clean create

clean:
	sudo rm -f /usr/local/bin/bouli-sandbox
	sudo rm -f /usr/local/bin/dev-sandbox
	sudo rm -f /usr/local/bin/bouli-garbage-collector
	sudo rm -f /usr/local/bin/dev-garbage-collector

	sudo rm -f /usr/local/bin/ai-ralph-opencode
	sudo rm -f /usr/local/bin/ai-ralph-codex
	sudo rm -f /usr/local/bin/ai-sbx-opencode
	sudo rm -f /usr/local/bin/ai-sbx-codex
	sudo rm -f /usr/local/bin/ai-lazy-init

	sudo rm -f /usr/local/bin/dev-push-loop
	sudo rm -f /usr/local/bin/dev-lazy-gh

	zsh

create:
#DEV
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/bouli-sandbox
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/dev-sandbox
	chmod +x $(PWD)/development/sandbox_launcher.sh

	sudo ln -s $(PWD)/development/clean_garbage_collector.sh /usr/local/bin/bouli-garbage-collector
	sudo ln -s $(PWD)/development/clean_garbage_collector.sh /usr/local/bin/dev-garbage-collector
	chmod +x $(PWD)/development/clean_garbage_collector.sh

	sudo ln -s $(PWD)/development/push_loop.sh /usr/local/bin/dev-push-loop
	chmod +x $(PWD)/development/push_loop.sh

	sudo ln -s $(PWD)/development/gh_lazy_init.sh /usr/local/bin/dev-lazy-gh
	chmod +x $(PWD)/development/gh_lazy_init.sh

#AI
	sudo ln -s $(PWD)/ai/sbx_opencode_ralph.sh /usr/local/bin/ai-ralph-opencode
	chmod +x $(PWD)/ai/sbx_opencode_ralph.sh

	sudo ln -s $(PWD)/ai/sbx_codex_ralph.sh /usr/local/bin/ai-ralph-codex
	chmod +x $(PWD)/ai/sbx_codex_ralph.sh

	sudo ln -s $(PWD)/ai/sbx_opencode.sh /usr/local/bin/ai-sbx-opencode
	chmod +x $(PWD)/ai/sbx_opencode.sh

	sudo ln -s $(PWD)/ai/sbx_codex.sh /usr/local/bin/ai-sbx-codex
	chmod +x $(PWD)/ai/sbx_codex.sh

	sudo ln -s $(PWD)/ai/ai_lazy_init.sh /usr/local/bin/ai-lazy-init
	chmod +x $(PWD)/ai/ai_lazy_init.sh

	zsh
