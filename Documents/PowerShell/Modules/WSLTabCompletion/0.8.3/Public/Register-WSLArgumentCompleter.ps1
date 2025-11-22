Function Register-WSLArgumentCompleter {
    . "$PSScriptRoot\..\Private\completerScriptBlock.ps1"
    Register-ArgumentCompleter -CommandName "wsl" `
        -ScriptBlock $Script:argCompFunction `
        -Native
}

# vim: ts=2 sts=2 sw=2 et
