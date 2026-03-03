# ███████╗███████╗██╗  ██╗
# ██╔════╝██╔════╝██║  ██║
# ███████╗███████╗███████║
# ╚════██║╚════██║██╔══██║
# ███████║███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# OpenSSH - Use Windows built-in for 1Password agent compatibility

# git-with-openssh (scoop) bundles OpenSSH 10.x which is incompatible
# with 1Password's named pipe SSH agent. The Windows built-in OpenSSH
# (9.5p2) works correctly. Git already uses core.sshCommand to point
# to the built-in, but direct ssh/scp/sftp commands need aliases too.

$winSshDir = "$env:SystemRoot\System32\OpenSSH"
if (Test-Path "$winSshDir\ssh.exe") {
    Set-Alias -Name ssh     -Value "$winSshDir\ssh.exe"     -Scope Global
    Set-Alias -Name ssh-add -Value "$winSshDir\ssh-add.exe" -Scope Global
    Set-Alias -Name scp     -Value "$winSshDir\scp.exe"     -Scope Global
    Set-Alias -Name sftp    -Value "$winSshDir\sftp.exe"    -Scope Global
}

# vim: ts=2 sts=2 sw=2 et
