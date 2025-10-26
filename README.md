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
6. Prompt the user whether to run fixnano (configures nano to enable mouse support and common key bindings - e.g. Ctrl+X = cut; Ctrl+V = Paste; Ctrl+S = Save, Ctrl+F = Find, etc.).

Usage (after cloning):

chmod +x init && ./init

---

## Scripts & (supporting) files
This table lists top-level files in the repository. Descriptions are taken from the first commented line of each file when present. To regenerate this table automatically, run the provided update-readme.sh generator which extracts first-line headers from scripts.
<!-- SCRIPTS_TABLE_START -->
| File | Description |
|---|---|
| [`.ai_prompts`](https://github.com/don-ferris/bash-scripts/blob/HEAD/.ai_prompts) | (no header) |
| [`.ai_prompts.bak`](https://github.com/don-ferris/bash-scripts/blob/HEAD/.ai_prompts.bak) | (no header) |
| [`ai_prompts.sh`](https://github.com/don-ferris/bash-scripts/blob/HEAD/ai_prompts.sh) | Menu system for managing frequently used Copilot prompts, placing them on the clipboard for quickly pasting into the prompt field. Run with -h to see all runtime options. |
| [`ai_prompts.sh.bak`](https://github.com/don-ferris/bash-scripts/blob/HEAD/ai_prompts.sh.bak) | ai_prompts.sh - Menu system for managing frequently used Copilot prompts, placing them on the clipboard for quickly pasting into the prompt field. Run with -h to see all runtime options. Author: Don Ferris/GitHub Copilot https://github.com/copilot/c/ba352956-6c0a-4180-8b7c-cce8d08e760f Created: 2025-10-23 Current Revision: v1.6 |
| [`.aliases`](https://github.com/don-ferris/bash-scripts/blob/HEAD/.aliases) | A collection of convenient, time saving keyboard shortcuts for commonly used BASH commands. |
| [`bwpwd`](https://github.com/don-ferris/bash-scripts/blob/HEAD/bwpwd) | programatically fetch passwords, secure notes, ssh keys from Bitwarden vault. Can be called from other scripts - see call_bwpwd for usage |
| [`call_bwpwd`](https://github.com/don-ferris/bash-scripts/blob/HEAD/call_bwpwd) | Companion script for bwpwd to demonstrate how to call it from other scripts. |
| [`etc-nanorc`](https://github.com/don-ferris/bash-scripts/blob/HEAD/etc-nanorc) | nanorc - nano (text editor) configuration file - modified nanorc file - preconfigured for mouse support and common key bindings |
| [`fixnano.sh`](https://github.com/don-ferris/bash-scripts/blob/HEAD/fixnano.sh) | installs a modified /etc/nanorc to enable mouse support and common keybindings in nano. |
| [`gitsync`](https://github.com/don-ferris/bash-scripts/blob/HEAD/gitsync) | Automate add/commit/pull(rebase)/push across GitHub accounts; auto-stage new files, rebase remote changes, handle conflicts, and auto-update the README table for repo after commits. |
| [`gitsync.bak.20251026014510`](https://github.com/don-ferris/bash-scripts/blob/HEAD/gitsync.bak.20251026014510) | gitsync - Automate add/commit/pull(rebase)/push across GitHub accounts; auto-stage new files, rebase remote changes, handle conflicts, and auto-update the README table for repo after commits. Author: Don Ferris/GitHub Copilot https://github.com/copilot/c/c5274c01-1515-4dbc-84e8-986126d37384 Created: 2025-10-15 Current Revision: v2.6 |
| [`gitsync.bak.20251026021534`](https://github.com/don-ferris/bash-scripts/blob/HEAD/gitsync.bak.20251026021534) | gitsync - Automate add/commit/pull(rebase)/push across GitHub accounts; auto-stage new files, rebase remote changes, handle conflicts, and auto-update the README table for repo after commits. Author: Don Ferris/GitHub Copilot https://github.com/copilot/c/c5274c01-1515-4dbc-84e8-986126d37384 Created: 2025-10-15 Current Revision: v2.6 |
| [`gitsync.bak.20251026022832`](https://github.com/don-ferris/bash-scripts/blob/HEAD/gitsync.bak.20251026022832) | gitsync - Automate add/commit/pull(rebase)/push across GitHub accounts; auto-stage new files, rebase remote changes, handle conflicts, and auto-update the README table for repo after commits. Author: Don Ferris/GitHub Copilot https://github.com/copilot/c/c5274c01-1515-4dbc-84e8-986126d37384 Created: 2025-10-15 Current Revision: v2.6 |
| [`gitsync.bak.20251026023428`](https://github.com/don-ferris/bash-scripts/blob/HEAD/gitsync.bak.20251026023428) | gitsync - Automate add/commit/pull(rebase)/push across GitHub accounts; auto-stage new files, rebase remote changes, handle conflicts, and auto-update the README table for repo after commits. Author: Don Ferris/GitHub Copilot https://github.com/copilot/c/c5274c01-1515-4dbc-84e8-986126d37384 Created: 2025-10-15 Current Revision: v2.7 |
| [`gitsync.bak.20251026025414`](https://github.com/don-ferris/bash-scripts/blob/HEAD/gitsync.bak.20251026025414) | gitsync - Automate add/commit/pull(rebase)/push across GitHub accounts; auto-stage new files, rebase remote changes, handle conflicts, and auto-update the README table for repo after commits. Author: Don Ferris/GitHub Copilot https://github.com/copilot/c/c5274c01-1515-4dbc-84e8-986126d37384 Created: 2025-10-15 Current Revision: v2.7 |
| [`gitsync.bak.20251026031554`](https://github.com/don-ferris/bash-scripts/blob/HEAD/gitsync.bak.20251026031554) | (no header) |
| [`init`](https://github.com/don-ferris/bash-scripts/blob/HEAD/init) | Post-clone setup: create/rename scripts dir, install .aliases, and update ~/.bashrc (optionally runs fixnano). |
| [`script_template.sh`](https://github.com/don-ferris/bash-scripts/blob/HEAD/script_template.sh) | # script_template.sh - Script template to insure consistency of script header (so that it's picked up properly by gitsync script for auto-updating the README for the repo. Author: Don Ferris Created: [[use current date for initial commit]] Current Revision: [[automatically set to top entry in Revision History]] |
| [`script_template.sh.bak`](https://github.com/don-ferris/bash-scripts/blob/HEAD/script_template.sh.bak) | # script_template.sh - Script template to insure consistency of script header (so that it's picked up properly by gitsync script for auto-updating the README for the repo. Author: Don Ferris Created: [[use current date for initial commit]] Current Revision: [[automatically set to top entry in Revision History]] |
| [`SrvSetup`](https://github.com/don-ferris/bash-scripts/blob/HEAD/SrvSetup) | Install Git and SSH keys, clone this repo, ensure .bashrc sources .aliases, optionally run fixnano, set hostname/IP, and optionally install Docker. |
<!-- SCRIPTS_TABLE_END -->
