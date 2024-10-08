# git-archive

This is a simple script that will help you archive and restore your git branches.

## Usage

```bash
git-archive [options] <put/restore> <branch>
```

### put

Puts the current branch into a new tag called `archive/<branch>` and removes the branch.

### restore

Restores the branch from the tag `archive/<branch>` and removes the tag.

## Options

```
  -h, --help            show this help message and exit
  -v, --verbose         verbose output
```

## Examples

```bash
# Archive the current branch
git-archive put

# Archive the branch 'test'
git-archive put test

# Restore the branch 'test'
git-archive restore test
```
