## About the `@.agents` folder

If you are `Claude`, use the `@.claude` folder instead of `@.agents` folder when it's referenced. i.e. `@.agents/issues` in Claude shoud be `@.claude/issues`

## Commit Rules

- When you make a git commit, always use `Semantic Commit Messages` described in the document `@.agents/code-standards/conventional-commits-messages.md` or `@.claude/code-standards/conventional-commits-messages.md`.
- When you create or update a "markdown" `.md` file in a "dot folder" `.folder` related to documentation, explanation, task/issue reporting or logging the work, use the skill `latest-commit` to track when exactly the file was created or updated.

## Unit Tests
- When you need to create unittests, use the file `@.agents/UNITTEST.md` or `@.claude/UNITTEST.md` as guidelines if you find it.
