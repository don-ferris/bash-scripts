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
| [`.aliases`](https://github.com/don-ferris/bash-scripts/blob/main/.aliases) | Aliases A collection of keyboard shortcuts to make the bash shell more intuitive and allow for faster command execution. alias alias_name="command_to_run" |
| [`etc-nanorc`](https://github.com/don-ferris/bash-scripts/blob/main/etc-nanorc) | modified nanorc file which configures the nano text editor for mouse support and to use common key bindings |
| [`fixnano.sh`](https://github.com/don-ferris/bash-scripts/blob/main/fixnano.sh) | a script to download and install a modified /etc/nanorc config file to enable mouse support in the nano text editor and to enable common key bindings (e.g. Ctrl+X = cut; Ctrl+V = Paste; Ctrl+S = Save, Ctrl+F = Find, etc.) |
| [`gitsync`](https://github.com/don-ferris/bash-scripts/blob/main/gitsync) | Automate Git add/commit/pull(rebase)/push workflows across multiple GitHub accounts. - Automatically stages new files by default (git add --all). - Commits staged changes when present (prompts for commit message). - Pulls with --rebase and handles conflicts interactively if they occur. - When a commit is created during sync, regenerates README table and commits+pushes it. - README table: single header row, File links to blob on current branch, Description concatenates comment block lines while skipping a leading comment that equals the filename. |
| [`init`](https://github.com/don-ferris/bash-scripts/blob/main/init) | Initialize this repo after cloning: - rename directory "bash-scripts" -> "scripts" (if applicable) - ensure $HOME/scripts exists and is added to PATH via ~/.bashrc (appended) - copy .aliases to $HOME/.aliases - append lines to ~/.bashrc to source ~/.aliases and add $HOME/scripts to PATH (if not already present) - source ~/.bashrc in the current shell and show loaded aliases - prompt (read -n 1) to run fixnano (enables nano mouse support and common key bindings) |
| [`SrvSetup`](https://github.com/don-ferris/bash-scripts/blob/main/SrvSetup) | This script installs Git, configures SSH keys, pulls my bash-scripts repo, ensures .bashrc sources .aliases, optionally runs fixnano.sh, Sets hostname, optionally sets static IP, and optionally installs Docker. |
<!-- SCRIPTS_TABLE_END -->
