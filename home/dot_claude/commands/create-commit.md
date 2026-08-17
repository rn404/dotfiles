---
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git commit:*)
description: Create commit message from the diff
---


1. Do NOT run `git add`. Files to be committed are already staged.
   Please check !`git diff --cached`, then make a commit message from the diff content
  - Format: `<type>(<scope>): <subject>` (scope is optional)
  - Subject should be in present tense and around 50 characters
  - Use these types:
    * feat: new feature for users
    * fix: bug fix for users
    * docs: documentation changes
    * style: formatting, missing semicolons, etc (no code change)
    * refactor: code restructuring without changing behavior
    * test: adding or refactoring tests
    * chore: updating build tasks, package manager configs, etc
    * build: changes to build system or dependencies
    * ci: CI configuration changes
    * perf: performance improvements
    * revert: reverting previous commits
  - See also: https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716
  - DO NOT include Co-Authored-By or any attribution lines
2. Check that the changes do not mix content based on more than one point of view. If there is more than one point of view, please feed this back to the user.
3. If all is well, confirm with the user that the COMMIT has been executed.

