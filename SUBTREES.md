# Git Subtrees

This repository uses a squashed Git subtree to vendor selected content from an
external repository while keeping it available as ordinary tracked files.

## Current subtree

| Item | Value |
| --- | --- |
| Upstream repository | `https://github.com/guillaumemeyer/watermarks-remover.git` |
| Upstream branch | `main` |
| Local prefix | `ai/lazy-ai-config/.agents/skills/remove-ai-marks` |
| Import mode | Squashed subtree |
| Initially imported filtered commit | `ee45ec95303cf4b480ef51ad1f1caae941f031bf` |
| Local squash commit | `57c0b1a2bdb79106027323a7e58f89ba64ee68fa` |
| Local merge commit | `b96727edd744e5c4ab39338bfb46257e4880d6c1` |

The subtree contains the upstream `skills/remove-ai-marks` directory rather
than the entire upstream working tree. Its `SKILL.md`, scripts, and references
are placed directly in the local agent-skills directory.

## How it was added

The subtree was added from a local filtered branch. The operation used was:

```sh
git remote add dep-watermarks-remover https://github.com/guillaumemeyer/watermarks-remover

git fetch dep-watermarks-remover

git branch dep-watermarks-remover-skill dep-watermarks-remover/main

git filter-branch \
  --prune-empty \
  --subdirectory-filter skills/remove-ai-marks \
  dep-watermarks-remover-skill

git subtree add \
  --prefix=ai/lazy-ai-config/.agents/skills/remove-ai-marks \
  dep-watermarks-remover-skill \
  --squash
```

The commands perform four steps:

1. Add and fetch the upstream repository as `dep-watermarks-remover`.
2. Create `dep-watermarks-remover-skill` from the upstream `main` branch.
3. Rewrite that local branch with `git filter-branch --subdirectory-filter`,
   making `skills/remove-ai-marks` the root of its history and removing empty
   commits.
4. Squash the filtered branch into the destination prefix with `git subtree
   add`.

The resulting filtered commit, `ee45ec9`, is rooted at the skill itself: its
top level contains `SKILL.md`, `references/`, and `scripts/`. `--squash`
condenses that filtered history into one local commit, after which Git creates
a merge commit carrying `git-subtree-dir` and `git-subtree-split` metadata.

Check the resulting layout after an import. The expected file is
`ai/lazy-ai-config/.agents/skills/remove-ai-marks/SKILL.md`, not a nested
`skills/remove-ai-marks/SKILL.md`.

## How it behaves

A subtree is stored as normal tracked files. Therefore:

- A regular `git clone` includes the complete skill.
- Contributors need no additional initialization after cloning.
- The parent repository records all imported files in its own commits.
- Local edits are possible, but can make later subtree pulls conflict.
- Upstream changes are not downloaded automatically; updates are explicit.

## Updating from upstream

Do **not** pull the upstream `main` branch directly into the local prefix. It is
rooted at the upstream repository, not at the individual skill, and would try
to import unrelated files.

First ensure the worktree is clean and fetch the existing dependency remote:

```sh
git status --short
git fetch dep-watermarks-remover
```

Save the currently imported filtered commit for comparison. Then reset the
local filtered branch to the new upstream `main` and filter it again. The `-f`
options are needed because both the branch and `filter-branch` backup from the
initial import already exist:

```sh
previous_skill_commit=ee45ec95303cf4b480ef51ad1f1caae941f031bf

git branch -f dep-watermarks-remover-skill dep-watermarks-remover/main

git filter-branch -f \
  --prune-empty \
  --subdirectory-filter skills/remove-ai-marks \
  dep-watermarks-remover-skill
```

For updates after the first one, set `previous_skill_commit` to the latest
`git-subtree-split` value in the most recent subtree squash commit. Review the
filtered changes, especially executable shell and Python files:

```sh
git diff "$previous_skill_commit"..dep-watermarks-remover-skill
```

Then pull the filtered branch into the existing prefix:

```sh
git subtree pull \
  --prefix=ai/lazy-ai-config/.agents/skills/remove-ai-marks \
  . \
  dep-watermarks-remover-skill \
  --squash
```

Here, `.` tells `git subtree pull` to fetch the filtered branch from the current
repository. Keeping the dependency remote and filtered branch makes later
updates repeatable. If no later updates are wanted, remove both explicitly:

```sh
git branch -D dep-watermarks-remover-skill
git remote remove dep-watermarks-remover
```

Afterward, inspect and test before pushing:

```sh
git show --stat --oneline HEAD
git diff HEAD^ -- ai/lazy-ai-config/.agents/skills/remove-ai-marks
```

If local modifications overlap upstream modifications, the pull may produce a
normal merge conflict. Resolve only after comparing both versions; otherwise
abort the merge with `git merge --abort` and retry from a clean state.

## Reverting an update

If a later subtree pull has already been committed, use `git revert` so the
rollback remains safe for shared history. A subtree pull normally creates a
merge commit. Find it with:

```sh
git log --merges --oneline -- ai/lazy-ai-config/.agents/skills/remove-ai-marks
```

Then revert it while retaining the first parent, which is this repository's
pre-update state:

```sh
git revert -m 1 <subtree-update-merge-commit>
```

Review the result with `git status` and `git diff HEAD^` before pushing. If the
pull is still in progress and has not been committed, use:

```sh
git merge --abort
```

## Removing the subtree

To stop shipping the skill while preserving an auditable history, remove its
tracked directory and commit the removal:

```sh
git rm -r ai/lazy-ai-config/.agents/skills/remove-ai-marks
git commit -m "chore(ai): remove remove-ai-marks subtree"
```

This is the clearest long-term removal method. It does not erase the previous
subtree commits, so the content remains recoverable from Git history.

To undo the original import specifically, use the recorded merge commit:

```sh
git revert -m 1 b96727edd744e5c4ab39338bfb46257e4880d6c1
```

That creates a new commit which removes the imported files without rewriting
shared history. Do not separately revert the squash commit: it is the second
parent of the subtree merge and is not on the repository's first-parent line.

## Restoring after removal

If removal was committed with `git rm`, restore the last version from the
commit immediately before the removal:

```sh
git restore --source=<commit-before-removal> -- \
  ai/lazy-ai-config/.agents/skills/remove-ai-marks
git commit -m "chore(ai): restore remove-ai-marks subtree"
```

This restores the files, but a future `git subtree pull` may need an explicit
re-import if the subtree ancestry was disrupted. In that case, commit or
remove the restored directory, recreate the filtered branch as described above,
and add that branch again at the local prefix.

## Inspecting subtree metadata

The metadata that links the local import to its upstream split is visible in
the squash commit message:

```sh
git show --no-patch --format=full 57c0b1a2bdb79106027323a7e58f89ba64ee68fa
```

The subtree relationship is represented by commit-message metadata rather than
a separate configuration file. Use the subtree commands in this document to
maintain the imported content.
