.PHONY: clean create

clean:
	sudo rm -f /usr/local/bin/bouli-sandbox | True
	sudo rm -f /usr/local/bin/dev-sandbox | True
	sudo rm -f /usr/local/bin/bouli-garbage-collector | True
	sudo rm -f /usr/local/bin/dev-garbage-collector | True

	sudo rm -f /usr/local/bin/ai-ralph-opencode | True
	sudo rm -f /usr/local/bin/ai-ralph-codex | True
	sudo rm -f /usr/local/bin/ai-ralph-claude | True
	sudo rm -f /usr/local/bin/ai-sbx-opencode | True
	sudo rm -f /usr/local/bin/ai-sbx-codex | True
	sudo rm -f /usr/local/bin/ai-sbx-claude | True
	sudo rm -f /usr/local/bin/ai-lazy-init | True

	sudo rm -f /usr/local/bin/dev-push-loop | True
	sudo rm -f /usr/local/bin/dev-lazy-gh | True

	zsh

create:
#DEV
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/bouli-sandbox | True
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/dev-sandbox | True
	chmod +x $(PWD)/development/sandbox_launcher.sh

	sudo ln -s $(PWD)/development/clean_garbage_collector.sh /usr/local/bin/bouli-garbage-collector | True
	sudo ln -s $(PWD)/development/clean_garbage_collector.sh /usr/local/bin/dev-garbage-collector | True
	chmod +x $(PWD)/development/clean_garbage_collector.sh

	sudo ln -s $(PWD)/development/push_loop.sh /usr/local/bin/dev-push-loop | True
	chmod +x $(PWD)/development/push_loop.sh

	sudo ln -s $(PWD)/development/gh_lazy_init.sh /usr/local/bin/dev-lazy-gh | True
	chmod +x $(PWD)/development/gh_lazy_init.sh

#AI
	sudo ln -s $(PWD)/ai/sbx_opencode_ralph.sh /usr/local/bin/ai-ralph-opencode | True
	chmod +x $(PWD)/ai/sbx_opencode_ralph.sh

	sudo ln -s $(PWD)/ai/sbx_claude_ralph.sh /usr/local/bin/ai-ralph-claude | True
	chmod +x $(PWD)/ai/sbx_claude_ralph.sh

	sudo ln -s $(PWD)/ai/sbx_codex_ralph.sh /usr/local/bin/ai-ralph-codex | True
	chmod +x $(PWD)/ai/sbx_codex_ralph.sh

	sudo ln -s $(PWD)/ai/sbx_opencode.sh /usr/local/bin/ai-sbx-opencode | True
	chmod +x $(PWD)/ai/sbx_opencode.sh

	sudo ln -s $(PWD)/ai/sbx_claude.sh /usr/local/bin/ai-sbx-claude | True
	chmod +x $(PWD)/ai/sbx_claude.sh

	sudo ln -s $(PWD)/ai/sbx_codex.sh /usr/local/bin/ai-sbx-codex | True
	chmod +x $(PWD)/ai/sbx_codex.sh

	sudo ln -s $(PWD)/ai/ai_lazy_init.sh /usr/local/bin/ai-lazy-init | True
	chmod +x $(PWD)/ai/ai_lazy_init.sh

	zsh
