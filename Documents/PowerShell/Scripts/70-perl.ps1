# ██████╗ ███████╗██████╗ ██╗
# ██╔══██╗██╔════╝██╔══██╗██║
# ██████╔╝█████╗  ██████╔╝██║
# ██╔═══╝ ██╔══╝  ██╔══██╗██║
# ██║     ███████╗██║  ██║███████╗
# ╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝
# Practical Extraction and Report Language

# Check if perl is available
if (-not (Get-Command perl -ErrorAction SilentlyContinue)) {
    return
}

# XDG-compliant path for cpanm (Perl module installer) cache
$env:PERL_CPANM_HOME = "$env:XDG_CACHE_HOME\cpanm"

# Ensure cpanm cache directory exists
if (-not (Test-Path $env:PERL_CPANM_HOME)) {
    New-Item -ItemType Directory -Path $env:PERL_CPANM_HOME -Force | Out-Null
}

# vim: ts=2 sts=2 sw=2 et
