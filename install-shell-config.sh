#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [[ "${TRACE-0}" == "1" ]]; then
  set -x
fi

log() {
  printf '[shell-bootstrap] %s\n' "$*"
}

fail() {
  printf '[shell-bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

if ! command -v apt-get >/dev/null 2>&1; then
  fail "This installer currently supports Ubuntu/Debian systems with apt-get."
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  require_command sudo
  SUDO="sudo"
fi

export DEBIAN_FRONTEND=noninteractive

BACKUP_ROOT="$HOME/.shell-bootstrap-backups"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

backup_file() {
  local file="$1"
  if [[ -e "$file" || -L "$file" ]]; then
    cp -a "$file" "$BACKUP_DIR/"
    log "Backed up $(basename "$file") to $BACKUP_DIR"
  fi
}

clone_or_update() {
  local repo_url="$1"
  local dest_dir="$2"
  local branch="${3-}"

  if [[ -d "$dest_dir/.git" ]]; then
    log "Updating $dest_dir"
    git -C "$dest_dir" pull --ff-only
    return
  fi

  rm -rf "$dest_dir"
  mkdir -p "$(dirname "$dest_dir")"

  if [[ -n "$branch" ]]; then
    log "Cloning $repo_url into $dest_dir (branch $branch)"
    git clone --depth 1 --branch "$branch" "$repo_url" "$dest_dir"
  else
    log "Cloning $repo_url into $dest_dir"
    git clone --depth 1 "$repo_url" "$dest_dir"
  fi
}

write_bashrc() {
  cat >"$HOME/.bashrc" <<'EOF'
# Enable the subsequent settings only in interactive sessions
case $- in
  *i*) ;;
    *) return;;
esac

export OSH="$HOME/.oh-my-bash"
OSH_THEME="font"

OMB_USE_SUDO=true

completions=(
  git
  composer
  ssh
)

aliases=(
  general
)

plugins=(
  git
  bashmarks
)

source "$OSH"/oh-my-bash.sh

export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  . "$NVM_DIR/nvm.sh"
fi
if [[ -s "$NVM_DIR/bash_completion" ]]; then
  . "$NVM_DIR/bash_completion"
fi

export BUN_INSTALL="$HOME/.bun"
if [[ -d "$BUN_INSTALL/bin" ]]; then
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

if [[ -r "$HOME/.dir_colors" ]]; then
  eval "$(dircolors -b "$HOME/.dir_colors")"
fi

# if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
#   exec tmux
# fi

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

if [[ -f "$HOME/.cargo/env" ]]; then
  . "$HOME/.cargo/env"
fi
EOF
}

write_profile() {
  cat >"$HOME/.profile" <<'EOF'
# ~/.profile: executed by the command interpreter for login shells.

if [ -n "$BASH_VERSION" ]; then
  if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
  fi
fi

if [ -d "$HOME/bin" ] ; then
  PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
  PATH="$HOME/.local/bin:$PATH"
fi

if [[ -f "$HOME/.cargo/env" ]]; then
  . "$HOME/.cargo/env"
fi
EOF
}

write_tmux_conf() {
  cat >"$HOME/.tmux.conf" <<'EOF'
set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins/'

set -g base-index 1
set -g pane-base-index 1

bind -n C-t new-window
bind -n C-PgDn next-window
bind -n C-PgUp previous-window
bind -n C-S-Left swap-window -t -1\; select-window -t -1
bind -n C-S-Right swap-window -t +1\; select-window -t +1
bind -n M-1 select-window -t 1
bind -n M-2 select-window -t 2
bind -n M-3 select-window -t 3
bind -n M-4 select-window -t 4
bind -n M-5 select-window -t 5
bind -n M-6 select-window -t 6
bind -n M-7 select-window -t 7
bind -n M-8 select-window -t 8
bind -n M-9 select-window -t:$
bind -n C-w kill-window
bind -n C-M-q confirm -p "Kill this tmux session?" kill-session
bind -n F11 resize-pane -Z
bind -n M-s split-window -hf
bind -n M-[ select-pane -t 1
bind -n M-] select-pane -t 2

set -g status-position top
set -g mouse on

bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
bind -n WheelDownPane select-pane -t= \; send-keys -M

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'arcticicestudio/nord-tmux'

run '~/.tmux/plugins/tpm/tpm'
EOF
}

write_dir_colors() {
  cat >"$HOME/.dir_colors" <<'EOF'
# Copyright (c) 2016-present Sven Greb <development@svengreb.de>
# This source code is licensed under the MIT license found in the license file.

COLOR tty

TERM alacritty
TERM alacritty-direct
TERM ansi
TERM *color*
TERM con[0-9]*x[0-9]*
TERM cons25
TERM console
TERM cygwin
TERM dtterm
TERM dvtm
TERM dvtm-256color
TERM Eterm
TERM eterm-color
TERM fbterm
TERM gnome
TERM gnome-256color
TERM hurd
TERM jfbterm
TERM konsole
TERM konsole-256color
TERM kterm
TERM linux
TERM linux-c
TERM mlterm
TERM putty
TERM putty-256color
TERM rxvt*
TERM rxvt-unicode
TERM rxvt-256color
TERM rxvt-unicode256
TERM screen*
TERM screen-256color
TERM st
TERM st-256color
TERM terminator
TERM tmux*
TERM tmux-256color
TERM vt100
TERM xterm*
TERM xterm-color
TERM xterm-88color
TERM xterm-256color
TERM xterm-kitty

#+-----------------+
#+ Global Defaults +
#+-----------------+
NORMAL 00
RESET 0

FILE 00
DIR 01;34
LINK 36
MULTIHARDLINK 04;36

FIFO 04;01;36
SOCK 04;33
DOOR 04;01;36
BLK 01;33
CHR 33

ORPHAN 31
MISSING 01;37;41

EXEC 01;36

SETUID 01;04;37
SETGID 01;04;37
CAPABILITY 01;37

STICKY_OTHER_WRITABLE 01;37;44
OTHER_WRITABLE 01;04;34
STICKY 04;37;44

#+-------------------+
#+ Extension Pattern +
#+-------------------+
#+--- Archives ---+
.7z 01;32
.ace 01;32
.alz 01;32
.arc 01;32
.arj 01;32
.bz 01;32
.bz2 01;32
.cab 01;32
.cpio 01;32
.deb 01;32
.dz 01;32
.ear 01;32
.gz 01;32
.jar 01;32
.lha 01;32
.lrz 01;32
.lz 01;32
.lz4 01;32
.lzh 01;32
.lzma 01;32
.lzo 01;32
.rar 01;32
.rpm 01;32
.rz 01;32
.sar 01;32
.t7z 01;32
.tar 01;32
.taz 01;32
.tbz 01;32
.tbz2 01;32
.tgz 01;32
.tlz 01;32
.txz 01;32
.tz 01;32
.tzo 01;32
.tzst 01;32
.war 01;32
.xz 01;32
.z 01;32
.Z 01;32
.zip 01;32
.zoo 01;32
.zst 01;32

#+--- Audio ---+
.aac 32
.au 32
.flac 32
.m4a 32
.mid 32
.midi 32
.mka 32
.mp3 32
.mpa 32
.mpeg 32
.mpg 32
.ogg 32
.opus 32
.ra 32
.wav 32

#+--- Customs ---+
.3des 01;35
.aes 01;35
.gpg 01;35
.pgp 01;35

#+--- Documents ---+
.doc 32
.docx 32
.dot 32
.odg 32
.odp 32
.ods 32
.odt 32
.otg 32
.otp 32
.ots 32
.ott 32
.pdf 32
.ppt 32
.pptx 32
.xls 32
.xlsx 32

#+--- Executables ---+
.app 01;36
.bat 01;36
.btm 01;36
.cmd 01;36
.com 01;36
.exe 01;36
.reg 01;36

#+--- Ignores ---+
*~ 02;37
.bak 02;37
.BAK 02;37
.log 02;37
.log 02;37
.old 02;37
.OLD 02;37
.orig 02;37
.ORIG 02;37
.swo 02;37
.swp 02;37

#+--- Images ---+
.bmp 32
.cgm 32
.dl 32
.dvi 32
.emf 32
.eps 32
.gif 32
.jpeg 32
.jpg 32
.JPG 32
.mng 32
.pbm 32
.pcx 32
.pgm 32
.png 32
.PNG 32
.ppm 32
.pps 32
.ppsx 32
.ps 32
.svg 32
.svgz 32
.tga 32
.tif 32
.tiff 32
.xbm 32
.xcf 32
.xpm 32
.xwd 32
.xwd 32
.yuv 32

#+--- Video ---+
.anx 32
.asf 32
.avi 32
.axv 32
.flc 32
.fli 32
.flv 32
.gl 32
.m2v 32
.m4v 32
.mkv 32
.mov 32
.MOV 32
.mp4 32
.mpeg 32
.mpg 32
.nuv 32
.ogm 32
.ogv 32
.ogx 32
.qt 32
.rm 32
.rmvb 32
.swf 32
.vob 32
.webm 32
.wmv 32
EOF
}

install_packages() {
  log "Updating apt package index"
  $SUDO apt-get update

  log "Installing packages"
  $SUDO apt-get install -y \
    bash-completion \
    ca-certificates \
    curl \
    fonts-powerline \
    git \
    tmux
}

install_oh_my_bash() {
  clone_or_update "https://github.com/ohmybash/oh-my-bash.git" "$HOME/.oh-my-bash"
}

install_tmux_plugins() {
  mkdir -p "$HOME/.tmux/plugins"
  clone_or_update "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"
  clone_or_update "https://github.com/tmux-plugins/tmux-sensible" "$HOME/.tmux/plugins/tmux-sensible"
  clone_or_update "https://github.com/arcticicestudio/nord-tmux" "$HOME/.tmux/plugins/nord-tmux"
}

main() {
  install_packages
  install_oh_my_bash
  install_tmux_plugins

  backup_file "$HOME/.bashrc"
  backup_file "$HOME/.profile"
  backup_file "$HOME/.tmux.conf"
  backup_file "$HOME/.dir_colors"
  backup_file "$HOME/.sdirs"

  write_bashrc
  write_profile
  write_tmux_conf
  write_dir_colors
  : >"$HOME/.sdirs"

  log "Shell configuration installed."
  log "Open a new shell or run: source ~/.bashrc"
  log "Start tmux with: tmux"
}

main "$@"
