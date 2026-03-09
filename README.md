# scripts

## Shell bootstrap

This repo includes a single-shot Ubuntu shell bootstrap that installs and configures:

- `tmux`
- TPM (`tmux-plugins/tpm`)
- `tmux-sensible`
- `nord-tmux`
- Oh My Bash with the `font` prompt theme
- custom `~/.bashrc`, `~/.profile`, `~/.tmux.conf`, and `~/.dir_colors`

Run it with:

```bash
curl -fsSL https://raw.githubusercontent.com/Dastari/scripts/main/install-shell-config.sh | bash
```

The script expects Ubuntu/Debian with `apt-get`, uses `sudo` when needed, and backs up any existing shell dotfiles into `~/.shell-bootstrap-backups/<timestamp>/`.
