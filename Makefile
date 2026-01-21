create:
	sudo ln -s $(PWD)/development/sandbox_launcher.sh /usr/local/bin/bouli-sandbox
	chmod +x ./development/sandbox_launcher.sh
	zsh

clean:
	sudo rm /usr/local/bin/bouli-sandbox
	zsh
