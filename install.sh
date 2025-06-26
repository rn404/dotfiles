#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v gh &>/dev/null; then
  echo "Installing Github cli..."
  brew install gh
  echo "[WARN] Please setup github auth"
  echo "[WARN] exec: gh auth login"
fi

if command -v asdf &>/dev/null; then
  echo "[WARN] SHOULD UNINSTALL asdf"
fi

# https://mise.jdx.dev/getting-started.html
if ! command -v mise &>/dev/null; then
  echo "Installing mise..."
  brew install mise
  if ! grep -q 'eval "$(mise activate zsh)"' ~/.zshrc 2>/dev/null; then
    echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
  else
    echo "Activation command already exists in ~/.zshrc"
  fi
  mise use --global node@latest
  mise use --global deno@latest
  mise list

  # https://docs.anthropic.com/ja/docs/claude-code/overview
  npm install -g @anthropic-ai/claude-code
fi

# https://neovim.io/
if ! command -v nvim &>/dev/null; then
  echo "Installing Neovim..."
  brew install neovim
fi

# https://www.lazyvim.org/installation
echo "Setting up LazyVim..."
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# copy neovim settings
echo "Copying config files..."
append_unique_config() {
  local source_file="$1"
  local target_file="$2"
  local marker="-- DOTFILES_CUSTOM_CONFIG"
  if grep -q "$marker" "$target_file" 2>/dev/null; then
    echo "Custom config already exists in $target_file"
    return
  fi
  {
    echo ""
    echo "$marker"
    cat "$source_file"
  } >>"$target_file"
}
append_unique_config "$SCRIPT_DIR/nvim/lua/config/keymaps.lua" "$HOME/.config/nvim/lua/config/keymaps.lua"
append_unique_config "$SCRIPT_DIR/nvim/lua/config/options.lua" "$HOME/.config/nvim/lua/config/options.lua"

# Start neovim
# nvim
