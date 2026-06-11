# Git Workflow

Every change reaches `main` through its own worktree, branch, and pull
request — `main` is never committed to directly. Claude authors the work; the
human reviews the PR before it merges. That review is the point of the flow.

## 1. Start a task

Work happens in an isolated worktree on a `feature/<slug>` branch, never in
the main checkout. In Claude Code, create it with the worktree tool, which
places the worktree under `.claude/worktrees/` and branches from the latest
`main`. By hand the equivalent is:

```bash
git worktree add -b feature/<slug> \
  .claude/worktrees/feature/<slug> origin/main
```

The pre-commit hook is shared from the main checkout, so a new worktree is
ready to commit immediately — no per-worktree setup.

## 2. Commit

Before each `git commit`, make sure every Markdown file passes lint:

1. From the repo root, run `markdownlint-cli2` (it reads its rules and file
   globs from `.markdownlint-cli2.jsonc`).
2. If it reports any errors, run `markdownlint-cli2 --fix` to auto-correct the
   mechanical ones, then fix anything left by hand.
3. Re-run `markdownlint-cli2` and repeat until it reports `0 error(s)`.
4. Only then create the commit.

The pre-commit hook enforces this on staged files as a backstop, but don't
lean on it — get the whole tree to `0 error(s)` first.

## 3. Open a pull request

Push the branch, then open a PR against `main`:

```bash
git push -u origin feature/<slug>
```

Create the PR with `gh pr create --fill` if the GitHub CLI is set up, or from
the compare link GitHub prints after the push. The human reviews the diff; do
not merge before it is approved.

## 4. Merge and clean up

After approval, squash-merge the PR — the GitHub "Squash and merge" button, or
`gh pr merge --squash --delete-branch`. Then tear down the worktree and branch:

```bash
git worktree remove .claude/worktrees/feature/<slug>
git branch -d feature/<slug>
```

Finally, sync the main checkout with the squashed commit:

```bash
git switch main   # in the main checkout
git pull
```
