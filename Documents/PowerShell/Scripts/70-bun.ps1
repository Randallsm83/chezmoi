# ██████╗ ██╗   ██╗███╗   ██╗
# ██╔══██╗██║   ██║████╗  ██║
# ██████╔╝██║   ██║██╔██╗ ██║
# ██╔══██╗██║   ██║██║╚██╗██║
# ██████╔╝╚██████╔╝██║ ╚████║
# ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝
# All-in-one JavaScript runtime

# Check if bun is available
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    return
}

# Bun configuration
# BUN_INSTALL is set in 50-mise.ps1 based on mise installation

# Bun aliases (similar to npm)
function bunx { bun x @args }
function buni { bun install @args }
function buna { bun add @args }
function bunad { bun add --dev @args }
function bunr { bun remove @args }
function bunrun { bun run @args }
function bunrd { bun run dev @args }
function bunrb { bun run build @args }
function bunt { bun test @args }

# vim: ts=2 sts=2 sw=2 et
