# bash-scripts

[![Repo Size](https://img.shields.io/badge/repo–tools-collection-blue)](https://github.com/don-ferris/bash-scripts)
![Bash](https://img.shields.io/badge/language-Bash-yellow)
![Debian-friendly](https://img.shields.io/badge/os-Debian%20based-lightgrey)

A collection of utility/helper (BASH) scripts and related files I wrote to make life at the command prompt a little faster, easier and more intuitive. Good for any (Debian-based) unless you spend ALL your time in the GUI. Below is a complete index of every script/config in the repository - auto-updated every time a script is added. Short descriptions are populated from each script's header (the first few commented lines in the script) when available.

---

## init

This repository includes a short init script that is intended to be run immediately after cloning. It activates all the goodies, performing the following actions:

1. Rename the current directory from "bash-scripts" to "scripts" (if the cwd is named "bash-scripts").
2. Ensure $HOME/scripts is added to PATH by updating ~/.bashrc.
3. Copy the repository's .aliases to $HOME/.aliases.
4. Appends to .bashrc - `source .aliases` and adds $HOME/scripts to PATH (existing ~/.bashrc will be backed up) so that all aliases and scripts are activated and ready to use.
5. Lists all loaded aliases.
6. Prompt the user (read -n 1) whether to run fixnano (configures nano to enable mouse support and common key bindings - e.g. Ctrl+X = cut; Ctrl+V = Paste; Ctrl+S = Save, Ctrl+F = Find, etc.).

Usage (after cloning):

chmod +x init && ./init

---

## Scripts & (supporting) files
This table lists top-level files in the repository. Descriptions are taken from the first commented line of each file when present. To regenerate this table automatically, run the provided update-readme.sh generator which extracts first-line headers from scripts.
<!-- SCRIPTS_TABLE_START -->
| File | Description |
|---|---|
| [`.aliases`](https://github.com/don-ferris/bash-scripts/blob/main/.aliases) | Aliases A collection of convenient, time saving aliases (keyboard shortcuts for commonly used BASH commands. |
| [`etc-nanorc`](https://github.com/don-ferris/bash-scripts/blob/main/etc-nanorc) | modified nanorc file - configures the nano text editor for mouse support and common key bindings |
| [`fixnano.sh`](https://github.com/don-ferris/bash-scripts/blob/main/fixnano.sh) | fixnano |
| [`gitsync`](https://github.com/don-ferris/bash-scripts/blob/main/gitsync) | Automate add/commit/pull(rebase)/push across GitHub accounts; auto-stage new files, rebase remote changes, handle conflicts, and auto-update the README table after commits. |
| [`init`](https://github.com/don-ferris/bash-scripts/blob/main/init) | Post-clone setup: create/rename scripts dir, install .aliases, and update ~/.bashrc (optionally runs fixnano). |
| [`SrvSetup`](https://github.com/don-ferris/bash-scripts/blob/main/SrvSetup) | (no header; inferred) |
<!-- SCRIPTS_TABLE_END -->
