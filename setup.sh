#!/usr/bin/env bash
#
# dotfiles setup (chezmoi-based)
#
# Usage:
#   ./setup.sh all [--with-personal-key]   Full common setup (optionally restore the personal key)
#   ./setup.sh homebrew                     Install Homebrew only (macOS)
#   ./setup.sh dotfiles                     Generate chezmoi config + apply only
#   ./setup.sh nvim                         Neovim and its config only (no root needed)
#   ./setup.sh tools                        Install CLI tools only
#   ./setup.sh ssh-key                      Restore the personal SSH key from Bitwarden only
#   ./setup.sh doctor [--record]            Check tool versions vs versions.lock (--record to re-baseline)
#
# Running with no command prints usage; nothing runs implicitly.
#
# Supports macOS (Homebrew) and Linux (apt + official installers).
# To restore the personal key, Bitwarden must be unlocked:
#   export BW_SESSION="$(bw unlock --raw)"
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
OS="$(uname -s)"                              # Darwin | Linux
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo"  # no-op when already root
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# ---- logging ----
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage:
  ./setup.sh all [--with-personal-key]   Full common setup (optionally restore the personal key)
  ./setup.sh homebrew                     Install Homebrew only (macOS)
  ./setup.sh dotfiles                     Generate chezmoi config + apply only
  ./setup.sh nvim                         Neovim and its config only (no root needed)
  ./setup.sh tools                        Install CLI tools only
  ./setup.sh ssh-key                      Restore the personal SSH key from Bitwarden only
  ./setup.sh doctor [--record]            Check tool versions vs versions.lock (--record to re-baseline)
EOF
}

# ---- helpers ----
have() { command -v "$1" >/dev/null 2>&1; }
brew_install() { have "$1" || brew install "${2:-$1}"; }

# ---- bootstrap (OS prerequisites) ----
ensure_base() {
  # Linux only: base tools macOS already ships (git/curl/compiler).
  [ "$OS" = Linux ] || return 0
  info "Installing base packages via apt..."
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq curl git ca-certificates build-essential unzip
}

ensure_homebrew() {
  [ "$OS" = Darwin ] || return 0             # Homebrew path is macOS-only here
  have brew && return
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon installs to /opt/homebrew, Intel to /usr/local.
  local brew_bin
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew_bin" ]; then
      eval "$("$brew_bin" shellenv)"
      return
    fi
  done
  warn "Homebrew was installed but brew was not found in the expected paths."
  return 1
}

ensure_xcode_clt() {
  [ "$OS" = Darwin ] || return 0             # Linux uses build-essential from ensure_base
  xcode-select -p >/dev/null 2>&1 && return
  info "Installing Xcode Command Line Tools (cc/make for treesitter)..."
  xcode-select --install || true
  warn "Finish the Xcode CLT installer dialog, then re-run 'tools' if needed."
}

# ---- installers (OS-aware) ----
install_chezmoi() {
  have chezmoi && return
  info "Installing chezmoi..."
  case "$OS" in
    Darwin) brew install chezmoi ;;
    Linux)  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" ;;
  esac
}

install_neovim_linux() {
  have nvim && return
  local arch nv
  arch="$(uname -m)"; [ "$arch" = aarch64 ] && nv=nvim-linux-arm64 || nv=nvim-linux-x86_64
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${nv}.tar.gz" | $SUDO tar xz -C /opt
  $SUDO ln -sf "/opt/${nv}/bin/nvim" /usr/local/bin/nvim
}

install_lazygit_linux() {
  have lazygit && return
  local arch lg ver
  arch="$(uname -m)"; [ "$arch" = aarch64 ] && lg=arm64 || lg=x86_64
  ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
         | grep -oE '"tag_name": *"v[0-9.]+"' | grep -oE 'v[0-9.]+' | head -1)"
  [ -n "$ver" ] || return 1
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/${ver}/lazygit_${ver#v}_Linux_${lg}.tar.gz" \
    | tar xz -C /tmp lazygit
  $SUDO install /tmp/lazygit /usr/local/bin/lazygit
}

# ---- units of work ----
apply_dotfiles() {
  install_chezmoi                            # required before 'chezmoi apply'
  if [ ! -f "$CHEZMOI_CONFIG" ]; then
    info "Generating chezmoi config (using this repo as source)..."
    local email work_ans work=false
    read -rp "Git email: " email
    read -rp "Is this a work machine? [y/N]: " work_ans
    [[ "$work_ans" =~ ^[Yy] ]] && work=true
    mkdir -p "$(dirname "$CHEZMOI_CONFIG")"
    cat > "$CHEZMOI_CONFIG" <<EOF
sourceDir = "$SCRIPT_DIR"

[data]
    email = "$email"
    work = $work
EOF
  fi
  info "Applying dotfiles (chezmoi apply)..."
  chezmoi apply
  ok "Dotfiles applied"
}

install_tools() {
  info "Installing CLI tools ($OS)..."
  case "$OS" in
    Darwin)
      brew_install gh
      brew_install nvim neovim
      brew_install mise
      brew_install starship                  # used by ~/.zshrc prompt
      brew_install rg ripgrep                # LazyVim: telescope search
      brew_install fd                        # LazyVim: file find
      brew_install lazygit                   # LazyVim: git UI
      ;;
    Linux)
      $SUDO apt-get install -y -qq ripgrep fd-find || warn "apt: ripgrep/fd-find failed"
      have gh || $SUDO apt-get install -y -qq gh || warn "install gh via your distro's repo"
      install_neovim_linux
      have mise     || curl -fsSL https://mise.run | sh
      have starship || curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
      install_lazygit_linux || warn "lazygit not installed (optional)"
      ;;
  esac

  info "Installing tools declared in mise config (node/deno/go/rust, etc.)..."
  mise install

  info "Installing Claude Code (native installer, auto-updates itself)..."
  if ! have claude; then
    curl -fsSL https://claude.ai/install.sh | bash || warn "Failed to install Claude Code."
  fi

  info "Installing global npm tools..."
  if ! mise exec -- npm install -g @google/gemini-cli; then
    warn "Failed to install global npm tools. Re-run after restarting your shell."
  fi

  if have gh; then
    warn "If GitHub auth is not set up yet:  gh auth login"
  fi
  ok "Tools installed"
}

restore_personal_key() {
  info "Restoring personal SSH key from Bitwarden..."
  if ! have bw; then
    warn "bw (Bitwarden CLI) not found. Install it and retry."
    return 1
  fi
  if [ -z "${BW_SESSION:-}" ] || \
     ! bw status --session "$BW_SESSION" 2>/dev/null | grep -q '"status":"unlocked"'; then
    warn 'Bitwarden is not unlocked. First run:  export BW_SESSION="$(bw unlock --raw)"'
    return 1
  fi

  # This function runs on the left of "||" in `all`, where set -e is disabled,
  # so every failure is handled explicitly. All files are prepared first, and
  # an existing different key is kept as a backup before it is replaced.
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh" || return 1
  local key="$HOME/.ssh/id_ed25519" tmp_dir pubkey email backup=""
  tmp_dir="$(mktemp -d "$HOME/.ssh/.restore.XXXXXX")" || return 1
  if ! bw get notes ssh-personal --session "$BW_SESSION" > "$tmp_dir/key" \
     || ! chmod 600 "$tmp_dir/key" \
     || ! pubkey="$(ssh-keygen -y -f "$tmp_dir/key")"; then
    rm -rf "$tmp_dir"
    warn "Could not fetch a valid key from Bitwarden. Existing key left untouched."
    return 1
  fi
  if ! email="$(chezmoi execute-template '{{ .email }}' 2>/dev/null)" || [ -z "$email" ]; then
    rm -rf "$tmp_dir"
    warn "Could not read email from the chezmoi config. Existing key left untouched."
    return 1
  fi

  # The public key and allowed_signers are regenerated from the private key
  # (these are deliberately NOT committed to the public repo).
  local key_type key_blob
  read -r key_type key_blob _ <<< "$pubkey"
  if ! printf '%s\n' "$pubkey" > "$tmp_dir/pub" \
     || ! chmod 644 "$tmp_dir/pub" \
     || ! printf '%s %s %s\n' "$email" "$key_type" "$key_blob" > "$tmp_dir/signers"; then
    rm -rf "$tmp_dir"
    warn "Could not prepare key files. Existing key left untouched."
    return 1
  fi

  if [ -e "$key" ] && ! cmp -s "$key" "$tmp_dir/key"; then
    backup="$key.bak-$(date +%Y%m%d%H%M%S)"
    if ! cp -p "$key" "$backup"; then
      rm -rf "$tmp_dir"
      warn "Could not back up the existing key. Existing key left untouched."
      return 1
    fi
  fi
  if ! mv "$tmp_dir/key" "$key" \
     || ! mv "$tmp_dir/pub" "$key.pub" \
     || ! mv "$tmp_dir/signers" "$HOME/.ssh/allowed_signers"; then
    rm -rf "$tmp_dir"
    warn "Key restore did not finish.${backup:+ Previous key saved at: $backup}"
    return 1
  fi
  rm -rf "$tmp_dir"
  [ -z "$backup" ] || warn "Previous key saved at: $backup"

  # .gitconfig enables commit signing only when the key exists; re-render it.
  chezmoi apply "$HOME/.gitconfig" || warn "Could not refresh .gitconfig. Run: chezmoi apply ~/.gitconfig"

  ok "Personal SSH key restored (id_ed25519 / .pub / allowed_signers)"
}

# Neovim and its config only: needs no root, no Homebrew, and no personal data.
# Tools come from mise, and nothing outside ~/.config/nvim is applied.
setup_nvim_only() {
  if ! have mise; then
    info "Installing mise..."
    curl -fsSL https://mise.run | sh
  fi
  info "Installing Neovim and its tools via mise..."
  mise use -g chezmoi neovim ripgrep fd lazygit tree-sitter
  mkdir -p "$HOME/.config"
  info "Applying the Neovim config..."
  mise exec -- chezmoi --source "$SCRIPT_DIR" apply "$HOME/.config/nvim"
  have cc || warn "No C compiler found: Neovim works, but Tree-sitter parsers cannot be built."
  ok "Neovim is ready. If nvim is not found, add ~/.local/share/mise/shims to PATH."
}

# ---- version drift (doctor) ----
VERSIONS_LOCK="${SCRIPT_DIR}/versions.lock"
DOCTOR_TOOLS="nvim mise chezmoi starship ripgrep fd lazygit gh"

# Print the normalized version of a tool, or empty when not installed.
# Each tool's --version format differs, so normalize per tool.
tool_version() {
  case "$1" in
    nvim)     have nvim     && nvim --version     | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v ;;
    mise)     have mise     && mise --version     | awk '{print $1}' ;;
    chezmoi)  have chezmoi  && chezmoi --version  | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v ;;
    starship) have starship && starship --version | head -1 | awk '{print $2}' ;;
    ripgrep)  have rg       && rg --version       | head -1 | awk '{print $2}' ;;
    fd)       have fd       && fd --version       | head -1 | awk '{print $2}' ;;
    lazygit)  have lazygit  && lazygit --version  | grep -oE 'version=[0-9][0-9.]*' | head -1 | cut -d= -f2 ;;
    gh)       have gh       && gh --version        | head -1 | awk '{print $3}' ;;
  esac
}

# Emit "tool=version" lines for every installed managed tool.
# mise-managed runtimes (node/deno/go/rust) are prefixed "mise:".
collect_versions() {
  local t v
  for t in $DOCTOR_TOOLS; do
    v="$(tool_version "$t" 2>/dev/null || true)"
    [ -n "$v" ] && printf '%s=%s\n' "$t" "$v"
  done
  if have mise; then
    mise ls --current 2>/dev/null \
      | awk 'NF>=2 && $1!="Tool" {print "mise:" $1 "=" $2}'
  fi
}

doctor() {
  local record=false
  [[ "${1:-}" == "--record" ]] && record=true

  if $record; then
    info "Recording current tool versions to versions.lock..."
    {
      echo "# versions.lock - baseline of managed tool versions."
      echo "# Check drift : ./setup.sh doctor"
      echo "# Re-baseline : ./setup.sh doctor --record"
      echo "# Format      : <tool>=<version>  (mise runtimes prefixed 'mise:')"
      collect_versions | sort
    } > "$VERSIONS_LOCK"
    ok "Recorded $(grep -c '=' "$VERSIONS_LOCK" || true) tools to $VERSIONS_LOCK"
    return 0
  fi

  info "Checking tool versions (current vs versions.lock)..."
  local current
  current="$(collect_versions | sort)"

  # No baseline yet: just show what's installed and how to record it.
  if [ ! -f "$VERSIONS_LOCK" ]; then
    warn "No versions.lock found - showing current versions only."
    warn "Create a baseline with:  ./setup.sh doctor --record"
    printf '%s\n' "$current" | while IFS='=' read -r t v; do
      [ -n "$t" ] && printf '  %-16s %s\n' "$t" "$v"
    done
    return 0
  fi

  printf '  %-16s %-14s %-14s %s\n' TOOL CURRENT EXPECTED STATUS
  local all_tools t cur exp drift=0 missing=0
  all_tools="$( { grep -v '^#' "$VERSIONS_LOCK"; printf '%s\n' "$current"; } \
                | grep '=' | cut -d= -f1 | sort -u || true)"
  for t in $all_tools; do
    exp="$(grep -E "^${t}=" "$VERSIONS_LOCK" | head -1 | cut -d= -f2- || true)"
    cur="$(printf '%s\n' "$current" | grep -E "^${t}=" | head -1 | cut -d= -f2- || true)"
    if [ -z "$cur" ]; then
      printf '  %-16s %-14s %-14s %s\n' "$t" "-" "$exp" "MISSING"; missing=$((missing+1))
    elif [ -z "$exp" ]; then
      printf '  %-16s %-14s %-14s %s\n' "$t" "$cur" "-" "untracked"
    elif [ "$cur" = "$exp" ]; then
      printf '  %-16s %-14s %-14s %s\n' "$t" "$cur" "$exp" "ok"
    else
      printf '  %-16s %-14s %-14s %s\n' "$t" "$cur" "$exp" "DRIFT"; drift=$((drift+1))
    fi
  done

  echo
  if [ "$drift" -eq 0 ] && [ "$missing" -eq 0 ]; then
    ok "All tracked tools match versions.lock."
  else
    warn "${drift} drifted, ${missing} missing. Align the tools, or re-baseline: ./setup.sh doctor --record"
  fi
}

# ---- entrypoint ----
main() {
  # -h/--help anywhere in the args prints usage and exits without running anything.
  for arg in "$@"; do
    case "$arg" in -h|--help) usage; return 0 ;; esac
  done

  local cmd="${1:-}"
  [ $# -gt 0 ] && shift

  case "$cmd" in
    all)
      local with_key=false
      [[ "${1:-}" == "--with-personal-key" ]] && with_key=true
      ensure_base
      ensure_homebrew
      ensure_xcode_clt
      apply_dotfiles
      install_tools
      if $with_key; then
        restore_personal_key || warn "Skipped/failed to restore the personal key"
      fi
      ;;
    homebrew)             ensure_homebrew ;;
    dotfiles)             ensure_base; ensure_homebrew; apply_dotfiles ;;
    tools)                ensure_base; ensure_homebrew; ensure_xcode_clt; install_tools ;;
    ssh-key|personal-key) restore_personal_key ;;
    nvim)                 setup_nvim_only ;;
    doctor)               doctor "$@" ;;
    "")                   usage ;;
    *) warn "unknown command: $cmd"; usage; return 1 ;;
  esac
}

main "$@"
