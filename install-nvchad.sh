#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [[ "${TRACE-0}" == "1" ]]; then
  set -x
fi

TOTAL_STEPS=10
CURRENT_STEP=0
LOG_FILE="$(mktemp -t nvchad-bootstrap.XXXXXX.log)"
USE_UNICODE_UI=0
SPINNER_FRAMES=('-' '\' '|' '/')
PROGRESS_FILL_CHAR='#'
PROGRESS_EMPTY_CHAR='-'
SUCCESS_MARK='OK'
FAIL_MARK='!!'

NVIM_CONFIG_DIR="$HOME/.config/nvim"
NVIM_SHARE_DIR="$HOME/.local/share/nvim"
NVIM_STATE_DIR="$HOME/.local/state/nvim"
BACKUP_ROOT="$HOME/.nvchad-bootstrap-backups"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

log() {
  printf '[nvchad-bootstrap] %s\n' "$*"
}

fail() {
  printf '[nvchad-bootstrap] ERROR: %s\n' "$*" >&2
  if [[ -f "$LOG_FILE" ]]; then
    printf '[nvchad-bootstrap] See log: %s\n' "$LOG_FILE" >&2
  fi
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

mkdir -p "$BACKUP_DIR"

cleanup() {
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    rm -f "$LOG_FILE"
  else
    printf '\n' >&2
  fi
}

trap cleanup EXIT

init_ui() {
  if [[ "${UNICODE_UI-}" == "1" ]]; then
    USE_UNICODE_UI=1
  fi

  if (( USE_UNICODE_UI )); then
    SPINNER_FRAMES=(⠁ ⠂ ⠄ ⡀ ⢀ ⠠ ⠐ ⠈)
    PROGRESS_FILL_CHAR='⣿'
    PROGRESS_EMPTY_CHAR='⣀'
    SUCCESS_MARK='✔'
    FAIL_MARK='✖'
  fi
}

render_progress_bar() {
  local width=10
  local filled=0
  local empty=0
  local fill_bar=""
  local empty_bar=""

  if (( TOTAL_STEPS > 0 )); then
    filled=$(( CURRENT_STEP * width / TOTAL_STEPS ))
  fi
  empty=$(( width - filled ))

  if (( filled > 0 )); then
    fill_bar="$(printf '%*s' "$filled" '' | tr ' ' "$PROGRESS_FILL_CHAR")"
  fi
  if (( empty > 0 )); then
    empty_bar="$(printf '%*s' "$empty" '' | tr ' ' "$PROGRESS_EMPTY_CHAR")"
  fi

  printf '%s%s' "$fill_bar" "$empty_bar"
}

start_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  printf '[%02d/%02d] %s %s\n' "$CURRENT_STEP" "$TOTAL_STEPS" "$(render_progress_bar)" "$1"
}

run_quiet() {
  local description="$1"
  shift

  start_step "$description"
  printf '      '

  "$@" >>"$LOG_FILE" 2>&1 &
  local cmd_pid=$!
  local frame_index=0

  while kill -0 "$cmd_pid" 2>/dev/null; do
    printf '\r      %s %s' "${SPINNER_FRAMES[$frame_index]}" "$description"
    frame_index=$(( (frame_index + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 0.1
  done

  wait "$cmd_pid" || {
    local exit_code=$?
    printf '\r      %s %s\n' "$FAIL_MARK" "$description" >&2
    tail -n 40 "$LOG_FILE" >&2 || true
    exit "$exit_code"
  }

  printf '\r      %s %s\n' "$SUCCESS_MARK" "$description"
}

backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    mv "$path" "$BACKUP_DIR/"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      NVIM_ARCHIVE="nvim-linux-x86_64.tar.gz"
      ;;
    aarch64|arm64)
      NVIM_ARCHIVE="nvim-linux-arm64.tar.gz"
      ;;
    *)
      fail "Unsupported architecture: $(uname -m)"
      ;;
  esac
}

install_packages() {
  run_quiet "Updating apt package index" $SUDO apt-get update
  run_quiet "Installing base packages" $SUDO apt-get install -y \
    ca-certificates \
    curl \
    fontconfig \
    gcc \
    git \
    make \
    npm \
    ripgrep \
    unzip \
    xz-utils
}

install_neovim() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ARCHIVE}" -o "$tmp_dir/$NVIM_ARCHIVE"
  tar -xzf "$tmp_dir/$NVIM_ARCHIVE" -C "$tmp_dir"

  $SUDO rm -rf /opt/nvim
  $SUDO mkdir -p /opt
  $SUDO cp -a "$tmp_dir/${NVIM_ARCHIVE%.tar.gz}" /opt/nvim
  $SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

  rm -rf "$tmp_dir"
}

install_nerd_font() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" -o "$tmp_dir/JetBrainsMono.tar.xz"
  tar -xJf "$tmp_dir/JetBrainsMono.tar.xz" -C "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  fc-cache -f "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"

  rm -rf "$tmp_dir"
}

install_tree_sitter_cli() {
  $SUDO npm install -g tree-sitter-cli
}

prepare_nvim_dirs() {
  backup_path "$NVIM_CONFIG_DIR"
  backup_path "$NVIM_SHARE_DIR"
  backup_path "$NVIM_STATE_DIR"

  mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"
  mkdir -p "$(dirname "$NVIM_SHARE_DIR")"
  mkdir -p "$(dirname "$NVIM_STATE_DIR")"
}

install_nvchad() {
  git clone https://github.com/NvChad/starter "$NVIM_CONFIG_DIR"
  rm -rf "$NVIM_CONFIG_DIR/.git"
}

bootstrap_lazy() {
  timeout 20m nvim --headless "+Lazy! sync" +qa
}

bootstrap_nvchad_extras() {
  timeout 20m nvim --headless "+MasonInstallAll" "+TSInstallAll" +qa
}

main() {
  init_ui
  detect_arch
  install_packages
  run_quiet "Installing latest stable Neovim" install_neovim
  run_quiet "Installing JetBrainsMono Nerd Font" install_nerd_font
  run_quiet "Installing tree-sitter CLI" install_tree_sitter_cli
  start_step "Backing up previous Neovim data"
  prepare_nvim_dirs
  printf '      %s %s\n' "$SUCCESS_MARK" "Backing up previous Neovim data"
  run_quiet "Cloning NvChad starter" install_nvchad
  run_quiet "Bootstrapping lazy.nvim plugins" bootstrap_lazy
  run_quiet "Running MasonInstallAll and TSInstallAll" bootstrap_nvchad_extras
  start_step "Final verification"
  nvim --version >>"$LOG_FILE" 2>&1
  printf '      %s %s\n' "$SUCCESS_MARK" "Final verification"

  log "NvChad installed."
  log "Set your terminal font to JetBrainsMono Nerd Font."
  log "Backups are in $BACKUP_DIR"
  log "Launch with: nvim"
}

main "$@"
