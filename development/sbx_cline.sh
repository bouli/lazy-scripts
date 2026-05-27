# draft
sbx rm cline | echo "Starting..."
sbx create --name cline shell .
sbx policy allow network cline localhost:11434
chmod +x ai_setup.sh
sbx exec cline ai_setup.sh

sbx exec cline "npm install -g n"
sbx exec cline curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
sbx exec cline sudo $(which n) lts
sbx exec cline hash -r
sbx exec cline npm install -g cline
sbx exec cline cline --auto-approve true "Find and use the files PRD.md @progress.txt\
\
1. Read the @PRD.md and @progress.txt file.\
2. Read ALL tasks. Find the next incomplete task and implement it.\
3. Create and use unit tests for the code to be sure that your code is working properly.\
4. Update @progress.txt with what you did.\
5. Commit your changes in the local repository.\
ONLY DO ONE TASK AT A TIME.\
  If the PRD is complete, output <promise>COMPLETE</promise>."
