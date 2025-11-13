#!/bin/bash
# Setup script for 1Password SSH integration in WSL
# This creates wrapper scripts to use Windows SSH with 1Password from WSL
#
# Usage: bash setup-1password-wsl.sh

set -e

echo "🔐 Setting up 1Password SSH integration for WSL..."
echo ""

# Create .local/bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Create SSH wrapper
cat > ~/.local/bin/ssh << 'EOF'
#!/bin/bash
# Wrapper to use Windows SSH with 1Password from WSL
/mnt/c/Windows/System32/OpenSSH/ssh.exe "$@"
EOF

# Create ssh-add wrapper
cat > ~/.local/bin/ssh-add << 'EOF'
#!/bin/bash
# Wrapper to use Windows ssh-add with 1Password from WSL
/mnt/c/Windows/System32/OpenSSH/ssh-add.exe "$@"
EOF

# Create scp wrapper
cat > ~/.local/bin/scp << 'EOF'
#!/bin/bash
# Wrapper to use Windows scp with 1Password from WSL
/mnt/c/Windows/System32/OpenSSH/scp.exe "$@"
EOF

# Create sftp wrapper
cat > ~/.local/bin/sftp << 'EOF'
#!/bin/bash
# Wrapper to use Windows sftp with 1Password from WSL
/mnt/c/Windows/System32/OpenSSH/sftp.exe "$@"
EOF

# Make all wrappers executable
chmod +x ~/.local/bin/ssh ~/.local/bin/ssh-add ~/.local/bin/scp ~/.local/bin/sftp

echo "✅ Created SSH wrappers in ~/.local/bin/"
echo ""

# Check if .local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "⚠️  ~/.local/bin is not in your PATH"
    echo ""
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    
    # Offer to add it automatically
    read -p "Add to PATH now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SHELL_RC=""
        if [ -f ~/.zshrc ]; then
            SHELL_RC=~/.zshrc
        elif [ -f ~/.bashrc ]; then
            SHELL_RC=~/.bashrc
        fi
        
        if [ -n "$SHELL_RC" ]; then
            echo "" >> "$SHELL_RC"
            echo "# 1Password SSH integration - use Windows SSH" >> "$SHELL_RC"
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
            echo "✅ Added to $SHELL_RC"
            echo "Run: source $SHELL_RC"
        else
            echo "❌ Could not find shell config file"
        fi
    fi
else
    echo "✅ ~/.local/bin is already in PATH"
fi

echo ""
echo "🧪 Testing setup..."
echo ""

# Test if Windows SSH is accessible
if [ -f /mnt/c/Windows/System32/OpenSSH/ssh.exe ]; then
    echo "✅ Windows SSH found"
    WIN_SSH_VERSION=$(/mnt/c/Windows/System32/OpenSSH/ssh.exe -V 2>&1)
    echo "   Version: $WIN_SSH_VERSION"
else
    echo "❌ Windows SSH not found at /mnt/c/Windows/System32/OpenSSH/ssh.exe"
    echo "   Install OpenSSH on Windows first"
    exit 1
fi

echo ""

# Test wrapper
if command -v ssh &> /dev/null; then
    WRAPPER_SSH_VERSION=$(ssh -V 2>&1)
    if [[ "$WRAPPER_SSH_VERSION" == *"OpenSSH"* ]]; then
        echo "✅ SSH wrapper working"
        echo "   $(which ssh)"
    else
        echo "⚠️  SSH command found but might not be using Windows SSH"
        echo "   $(which ssh)"
    fi
else
    echo "⚠️  SSH command not found - restart shell or source your config"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Restart your shell or run: source ~/.zshrc (or ~/.bashrc)"
echo "2. Test with: ssh-add -l"
echo "3. Should see your 1Password SSH keys"
echo "4. Configure SSH hosts in: /mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')/.ssh/config"
echo ""
echo "For more info, see: README-1PASSWORD-SSH.md"
