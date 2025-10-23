# bash-scripts

[![Repo Size](https://img.shields.io/badge/repo–tools-collection-blue)](https://github.com/don-ferris/bash-scripts)
![Bash](https://img.shields.io/badge/language-Bash-yellow)
![Debian-friendly](https://img.shields.io/badge/os-Debian%20based-lightgrey)

A collection of bash scripts and related files I wrote to make my life easier and to make any (Debian-based) client or server machine behave the way I like. Below is a full, eye‑friendly index of every script/config in the repository. Short descriptions are populated from each script's header (the first commented line) when available.

---

## init

This repository includes a short init script that is intended to be run immediately after cloning. It performs the following actions:

1. Rename the current directory from "bash-scripts" to "scripts" (if the cwd is named "bash-scripts").
2. Ensure $HOME/scripts is added to PATH by updating ~/.bashrc.
3. Copy the repository's .aliases to $HOME/.aliases.
4. Write a minimal ~/.bashrc that sources ~/.aliases and adds $HOME/scripts to PATH (existing ~/.bashrc will be backed up).
5. Source the new ~/.bashrc in the current shell and run the alias command to show loaded aliases.
6. Prompt the user (read -n 1) whether to run fixnano (configures nano to enable mouse support and useful key bindings).

Usage (after cloning):

chmod +x init && ./init

---

## Scripts & files
This table lists top-level files in the repository. Descriptions are taken from the first commented line of each file when present. To regenerate this table automatically, run the provided update-readme.sh generator which extracts first-line headers from scripts.
<!-- BEGIN SCRIPTS -->
| File | Type | Description (first comment line if present) | Raw link |
|---|---:|---|---|
<!-- END SCRIPTS -->

<!-- SCRIPTS_TABLE_START -->
| File | Type | Description (first comment line if present) | Notes |
|---|---:|---|---|
| `.aliases` | config | Aliases |  |
| `etc-nanorc` | script | etc-nanorc |  |
| `fixnano.sh` | script | fixnano.sh |  |
| `gitsync` | script | gitsync |  |
| `init` | file | init |  |
| `SrvSetup` | script | SrvSetup |  |
<!-- SCRIPTS_TABLE_END -->
