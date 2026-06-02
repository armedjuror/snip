<div align="center">

# snip

**Turn long shell commands into short ones.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: POSIX](https://img.shields.io/badge/Shell-POSIX-green.svg)]()
[![Platform: macOS | Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)]()

```sh
# Before
ssh -i ~/.ssh/key.pem ubuntu@3.192.168.1

# After
prodserver
```

</div>

---

## Table of Contents

- [Overview](#overview)
- [Install](#install)
- [Commands](#commands)
- [Usage](#usage)
- [How It Works](#how-it-works)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

`snip` is a lightweight, POSIX-compliant CLI tool that lets you create named shell functions for any command or sequence of commands. Snips support arguments, multi-line commands, and are stored in a plain shell file sourced into your rc — no daemons, no databases, no dependencies.

- **Zero dependencies** — pure POSIX sh, works on bash 3.2+, zsh, dash
- **Argument-aware** — pass positional args or forward everything with `"$@"`
- **Editor-first** — opens your `$EDITOR` for writing multi-line commands naturally
- **Non-destructive** — all snips live in `~/.snip/snips.<shell>`, easy to inspect and edit manually

---

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/yourusername/snip/main/install.sh | bash
```

Then reload your shell:

```sh
# zsh
source ~/.zshrc

# bash
source ~/.bashrc
```

The installer:
1. Detects your shell from `$SHELL`
2. Downloads `snip.sh` to `~/.snip/`
3. Creates `~/.snip/snips.<shell>` to store your snips
4. Adds a `snip` command to `~/.local/bin`
5. Sources the snips file from your rc file

> **Requirements:** `curl` or `wget`, a POSIX-compatible shell (bash or zsh), and `~/.local/bin` on your `$PATH` (the installer adds this automatically).

---

## Commands

| Command | Alias | Description |
|---|---|---|
| `snip add <name>` | | Create a new snip (opens `$EDITOR`) |
| `snip remove <name>` | `snip rm <name>` | Delete a snip |
| `snip list` | `snip ls` | List all snips with their commands |
| `snip help` | | Show help |
| `snip version` | `snip -v` | Show installed version |
| `snip uninstall` | | Remove snip from your system |

---

## Usage

### Simple command alias

```sh
snip add prodserver
```

Your `$EDITOR` opens with a template. Write the command:

```sh
ssh -i ~/.ssh/key.pem ubuntu@3.192.168.5
```

Save and quit. Now `pocketlog` is available in your shell.

```sh
pocketlog
# → ssh -i ~/.ssh/reeld.pem ubuntu@3.110.114.90
```

---

### Positional arguments

Use `$1`, `$2`, ... for positional args:

```sh
snip add pi
```

```sh
pip install $1 && pip freeze > requirements.txt
```

```sh
pi flask
# → pip install flask && pip freeze > requirements.txt

pi "django>=4.0"
# → pip install django>=4.0 && pip freeze > requirements.txt
```

---

### Forward all arguments

Use `"$@"` to pass everything through. Ideal for wrapping existing commands:

```sh
snip add gp
```

```sh
git pull "$@"
```

```sh
gp origin main
# → git pull origin main

gp --rebase origin main
# → git pull --rebase origin main
```

---

### Multi-line commands

Your editor handles multi-line freely:

```sh
snip add deploy
```

```sh
git pull "$@"
npm run build
pm2 restart app
echo "Deployed."
```

---

### Overwriting a snip

Running `snip add <name>` on an existing snip shows the current definition and asks for confirmation before opening the editor.

---

## How It Works

Snips are plain shell functions stored in `~/.snip/snips.<shell>`:

```sh
# ~/.snip/snips.zsh

prodserver() {
  ssh -i ~/.ssh/key.pem ubuntu@3.19.168.8
}

pi() {
  pip install $1 && pip freeze > requirements.txt
}
```

This file is sourced into your shell via a single line added to your `~/.zshrc` or `~/.bashrc` during install:

```sh
[ -f "/Users/you/.snip/snips.zsh" ] && . "/Users/you/.snip/snips.zsh" # snip managed
```

Since snips are just functions, they run in your current shell environment with full access to your aliases, env vars, and PATH. No subprocess overhead.

**File structure:**

```
~/.snip/
├── snip.sh          # the CLI
├── snips.zsh        # your snips (zsh)
├── snips.bash       # your snips (bash)
└── .shell           # detected shell, written at install time
```

---

## Uninstall

```sh
snip uninstall
```

This removes `~/.snip/` and cleans the snip-managed lines from your rc file. Your terminal is left exactly as it was before install.

---

## Contributing

Contributions are welcome. `snip` is intentionally small — please keep changes focused and POSIX-compatible.

### Getting started

```sh
git clone https://github.com/yourusername/snip.git
cd snip
```

No build step. Edit `snip.sh` and test directly:

```sh
sh snip.sh help
sh snip.sh add <name>
```

### Guidelines

- **POSIX sh only** — no bashisms, no external dependencies beyond `grep`, `sed`, `awk`, `mktemp`. Test with `dash -n` before submitting.
- **One concern per PR** — bug fixes, new commands, and refactors in separate PRs.
- **Test on both shells** — verify behaviour on zsh and bash before opening a PR.
- **Keep it small** — if a feature would be better served by rewriting in Go or another language, open an issue to discuss first.

### Reporting issues

Please include:
- Your OS and version
- Your shell (`echo $SHELL`) and version (`zsh --version` or `bash --version`)
- The exact command you ran and the output

---

## License

MIT License — see [LICENSE](LICENSE) for full text.

Copyright (c) 2025 yourusername
