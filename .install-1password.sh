#!/bin/sh
# Install 1Password CLI before chezmoi reads source state
# This ensures `onepassword` template function works

# Exit if already installed
type op >/dev/null 2>&1 && exit 0

echo "Installing 1Password CLI..."

# Detect OS
case "$(uname -s)" in
Darwin)
    # macOS
    if type brew >/dev/null 2>&1; then
        brew install --cask 1password-cli
        exit 0
    fi
    echo "Error: Homebrew not found" >&2
    exit 1
    ;;
Linux)
    # Linux - prefer mise for consistency across platforms
    if type mise >/dev/null 2>&1; then
        mise install 1password-cli@latest
        exit 0
    fi
    
    # Fallback to package manager
    if type pacman >/dev/null 2>&1; then
        # Arch Linux - use AUR helper if available, otherwise manual build
        if type yay >/dev/null 2>&1; then
            yay -S --noconfirm 1password-cli
            exit 0
        elif type paru >/dev/null 2>&1; then
            paru -S --noconfirm 1password-cli
            exit 0
        else
            # Manual AUR build (skip GPG check since key may not be imported)
            tmpdir=$(mktemp -d)
            git clone https://aur.archlinux.org/1password-cli.git "$tmpdir/1password-cli"
            cd "$tmpdir/1password-cli" && makepkg -si --noconfirm --skippgpcheck
            rm -rf "$tmpdir"
            exit 0
        fi
    elif type apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
            sudo tee /etc/apt/sources.list.d/1password.list
        sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
        curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
            sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
        sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
        sudo apt-get update && sudo apt-get install -y 1password-cli
        exit 0
    elif type dnf >/dev/null 2>&1; then
        # Fedora/RHEL
        sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
        sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
        sudo dnf install -y 1password-cli
        exit 0
    fi
    
echo "Error: No supported package manager found (mise, pacman, apt, or dnf)" >&2
    exit 1
    ;;
*)
    echo "Error: Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac
