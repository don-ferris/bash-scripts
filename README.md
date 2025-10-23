# bash-scripts

[![Repo Size](https://img.shields.io/badge/repo–tools-collection-blue)](https://github.com/don-ferris/bash-scripts)
![Bash](https://img.shields.io/badge/language-Bash-yellow)
![Debian-friendly](https://img.shields.io/badge/os-Debian%20based-lightgrey)

A small collection of bash scripts and related files I wrote to make life easier and to make any (Debian-based) client or server machine behave the way I like. Below is a full, eye‑friendly index of every script/config in the repository. Short descriptions are populated from each script's header (the first commented line) when available.

---

## init

This repository includes a short init script (named "init", no extension) intended to be run immediately after cloning. It performs the following actions:

1. Rename the current directory from "bash-scripts" to "scripts" (if the cwd is named "bash-scripts").
2. Ensure $HOME/scripts is added to PATH by updating ~/.bashrc.
3. Copy the repository's .aliases to $HOME/.aliases.
4. Write a minimal ~/.bashrc that sources ~/.aliases and adds $HOME/scripts to PATH (existing ~/.bashrc will be backed up).
5. Source the new ~/.bashrc in the current shell and run the alias command to show loaded aliases.
6. Prompt the user (read -n 1) whether to run fixnano (configures nano to enable mouse support and useful key bindings).

Usage (after cloning):

chmod +x init && ./init

---

## Scripts & files (table)
This table lists top-level files in the repository. Descriptions are taken from the first commented line of each file when present. To regenerate this table automatically, run the provided update-readme.sh generator which extracts first-line headers from scripts.

<!-- SCRIPTS_TABLE_START -->
| File | Type | Description (first comment line if present) | Raw link |
|---|---:|---|---|
<!-- SCRIPTS_TABLE_END -->

---

## Auto-update from script headers

The repository includes a generator script update-readme.sh that scans top-level files, extracts the first non-empty commented line from each script (the header), and updates the README table between the markers <!-- SCRIPTS_TABLE_START --> and <!-- SCRIPTS_TABLE_END -->. Run it after adding or editing scripts to refresh the README table.
