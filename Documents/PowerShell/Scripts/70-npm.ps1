# ███╗   ██╗██████╗ ███╗   ███╗
# ████╗  ██║██╔══██╗████╗ ████║
# ██╔██╗ ██║██████╔╝██╔████╔██║
# ██║╚██╗██║██╔═══╝ ██║╚██╔╝██║
# ██║ ╚████║██║     ██║ ╚═╝ ██║
# ╚═╝  ╚═══╝╚═╝     ╚═╝     ╚═╝
# Node Package Manager

# Check if npm is available
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    return
}

# =================================================================================================
# npm Aliases
# =================================================================================================
# Mirrors zsh npm plugin aliases

# Install globally
function npmg { npm i -g @args }

# Install and save to dependencies
function npmS { npm i -S @args }

# Install and save to dev-dependencies
function npmD { npm i -D @args }

# Force npm to fetch remote resources
function npmF { npm i -f @args }

# Execute command from node_modules folder
function npmE {
    $npmBin = npm bin
    $env:PATH = "$npmBin;$env:PATH"
    & @args
}

# Check outdated packages
function npmO { npm outdated @args }

# Update all packages
function npmU { npm update @args }

# Check npm version
function npmV { npm -v @args }

# List packages
function npmL { npm list @args }

# List top-level packages
function npmL0 { npm ls --depth=0 @args }

# npm scripts
function npmst { npm start @args }
function npmt { npm test @args }
function npmR { npm run @args }
function npmP { npm publish @args }
function npmI { npm init @args }
function npmi { npm info @args }
function npmSe { npm search @args }

# Common npm run scripts
function npmrd { npm run dev @args }
function npmrb { npm run build @args }

# vim: ts=2 sts=2 sw=2 et
