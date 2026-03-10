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

## NvChad bootstrap

This repo also includes a fresh-machine NvChad bootstrap for Ubuntu/Debian. It installs:

- latest stable Neovim
- `ripgrep`, `gcc`, `make`, `npm`, and `tree-sitter-cli`
- JetBrainsMono Nerd Font
- NvChad starter config
- plugin/bootstrap steps for `Lazy`, `MasonInstallAll`, and `TSInstallAll`

Run it with:

```bash
curl -fsSL https://raw.githubusercontent.com/Dastari/scripts/main/install-nvchad.sh | bash
```

If you want to install the required font from Windows PowerShell, run:

```powershell
& ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/jpawlowski/nerd-fonts-installer-PS/main/Invoke-NerdFontInstaller.ps1'))) -Name jetbrains-mono
```

After installing the font, set your terminal/editor font to `JetBrainsMono Nerd Font`.
