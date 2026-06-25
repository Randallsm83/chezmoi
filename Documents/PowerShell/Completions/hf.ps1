# Hugging Face CLI completion for PowerShell
if (Get-Command hf -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName hf -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        $previousComplete = $env:_HF_COMPLETE
        $previousArgs = $env:_TYPER_COMPLETE_ARGS
        $previousWord = $env:_TYPER_COMPLETE_WORD_TO_COMPLETE

        try {
            $env:_HF_COMPLETE = 'complete_powershell'
            $env:_TYPER_COMPLETE_ARGS = $commandAst.ToString()
            $env:_TYPER_COMPLETE_WORD_TO_COMPLETE = $wordToComplete

            & hf 2>$null | ForEach-Object {
                $commandArray = $_ -split ':::', 2
                if ($commandArray.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($commandArray[0])) {
                    $command = $commandArray[0]
                    $helpString = if ($commandArray.Count -gt 1) { $commandArray[1] } else { $command }
                    [System.Management.Automation.CompletionResult]::new(
                        $command,
                        $command,
                        [System.Management.Automation.CompletionResultType]::ParameterValue,
                        $helpString
                    )
                }
            }
        } finally {
            $env:_HF_COMPLETE = $previousComplete
            $env:_TYPER_COMPLETE_ARGS = $previousArgs
            $env:_TYPER_COMPLETE_WORD_TO_COMPLETE = $previousWord
        }
    }
}

# vim: ts=2 sts=2 sw=2 et
