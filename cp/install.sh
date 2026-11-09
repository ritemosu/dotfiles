#!/bin/sh
# Set up the competitive programming environment (macOS / Ubuntu).
# usage: sh ~/dotfiles/cp/install.sh
set -eu

dot="$(cd "$(dirname "$0")/.." && pwd)"
root=${CP_ROOT:-$HOME/CP}
bin="$HOME/.local/bin"
mkdir -p "$bin"
export PATH="$bin:$PATH"

# Packages (Ubuntu only; macOS uses Xcode clang + Homebrew).
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y g++ clangd git git-lfs curl python3 pipx xclip wl-clipboard xdg-utils
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL: wslview opens URLs in the Windows browser; win32yank shares the clipboard.
        sudo apt-get install -y wslu unzip
        if ! command -v win32yank.exe >/dev/null 2>&1; then
            tmp=$(mktemp -d)
            curl -fsSL -o "$tmp/w.zip" https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip
            unzip -o -q "$tmp/w.zip" win32yank.exe -d "$bin"
            chmod +x "$bin/win32yank.exe"
            rm -rf "$tmp"
        fi
    fi
    # clangd picks the newest GCC directory; its libstdc++ headers must exist,
    # or clangd reports "'bits/stdc++.h' file not found".
    gccver=$(ls /usr/lib/gcc/*-linux-gnu/ 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -1)
    [ -n "$gccver" ] && sudo apt-get install -y "libstdc++-$gccver-dev" || true

    # Neovim 0.11+ (apt's version is too old): official release in ~/.local/nvim.
    need_nvim=1
    if command -v nvim >/dev/null 2>&1; then
        minor=$(nvim --version | head -1 | sed -n 's/^NVIM v0\.\([0-9]*\).*/\1/p')
        [ -n "$minor" ] && [ "$minor" -ge 11 ] && need_nvim=0
    fi
    if [ "$need_nvim" = 1 ]; then
        case "$(uname -m)" in aarch64|arm64) arch=arm64 ;; *) arch=x86_64 ;; esac
        rm -rf "$HOME/.local/nvim"
        mkdir -p "$HOME/.local/nvim"
        curl -fL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz" \
            | tar xz -C "$HOME/.local/nvim" --strip-components=1
        ln -sf "$HOME/.local/nvim/bin/nvim" "$bin/nvim"
    fi
fi

# online-judge-tools, patched for AtCoder's "MiB" memory limit.
if ! command -v oj >/dev/null 2>&1; then
    pipx install online-judge-tools
    # oj imports distutils, removed in Python 3.12; setuptools provides it.
    pipx inject online-judge-tools setuptools
fi
oj_python=$(head -1 "$(command -v oj)" | sed 's/^#! *//')
"$oj_python" "$dot/cp/patch-oj.py"

# Neovim config
mkdir -p "$HOME/.config"
if [ -e "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$(date +%s)"
fi
ln -sfn "$dot/nvim/nvim" "$HOME/.config/nvim"

# Git: include the shared settings, link the global ignore file.
git config --global --get-all include.path | grep -qx "$dot/git/config" \
    || git config --global --add include.path "$dot/git/config"
mkdir -p "$HOME/.config/git"
if [ ! -e "$HOME/.config/git/ignore" ] || cmp -s "$HOME/.config/git/ignore" "$dot/git/ignore"; then
    ln -sf "$dot/git/ignore" "$HOME/.config/git/ignore"
fi
git config --global user.name >/dev/null || echo "git: set user.name / user.email (git config --global user.name ...)"

# Commands -> ~/.local/bin
for f in "$dot"/cp/bin/*; do
    ln -sf "$f" "$bin/$(basename "$f")"
done

# CP root: clangd config, AtCoder Library, CP_Library (for :NAME / Space l)
mkdir -p "$root"
cp "$dot/cp/compile_flags.txt" "$dot/cp/.clangd" "$root/"
if [ ! -d "$root/atcoder" ] && [ ! -d "$root/ac-library" ]; then
    git clone --depth 1 https://github.com/atcoder/ac-library "$root/ac-library"
fi
if [ ! -d "$root/CP_Library" ]; then
    # Private repository: needs an SSH key registered on GitHub.
    git clone git@github.com:Keita-Kindai/CP_Library.git "$root/CP_Library" \
        || echo "CP_Library: clone failed (register an SSH key, then clone it to $root/CP_Library)"
fi

# WezTerm config: link on macOS / Linux desktop (WSL copies it to Windows below).
if ! grep -qi microsoft /proc/version 2>/dev/null; then
    if [ -e "$HOME/.config/wezterm" ] && [ ! -L "$HOME/.config/wezterm" ]; then
        mv "$HOME/.config/wezterm" "$HOME/.config/wezterm.backup.$(date +%s)"
    fi
    ln -sfn "$dot/wezterm" "$HOME/.config/wezterm"
fi

# WSL: copy the WezTerm config to the Windows side (%USERPROFILE%\.config\wezterm).
# Windows cannot follow WSL symlinks, so this is a copy; re-run after changes.
if grep -qi microsoft /proc/version 2>/dev/null; then
    winhome=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null || true)
    if [ -n "$winhome" ] && [ -d "$winhome" ]; then
        mkdir -p "$winhome/.config/wezterm"
        cp "$dot"/wezterm/*.lua "$winhome/.config/wezterm/"
        echo "wezterm: config copied to $winhome/.config/wezterm"
    fi
    # Windows Terminal: colors, transparency, Alt key bindings (see windows-terminal/).
    for wt in "$winhome"/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json \
              "$winhome"/AppData/Local/Microsoft/Windows\ Terminal/settings.json; do
        [ -f "$wt" ] && python3 "$dot/windows-terminal/apply.py" "$wt"
    done
fi

echo
echo "done."
echo "If 'cpnew' is not found in a new terminal, log out and in again (or run: source ~/.profile)."
