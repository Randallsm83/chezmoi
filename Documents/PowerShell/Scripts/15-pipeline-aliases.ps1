# ================================================================================================
# Pipeline "global aliases" (zsh-style)
# ================================================================================================
# Lets you write   `cmd args G pattern`   instead of   `cmd args | G pattern`.
# Same for H (head), T (tail), L (less). Triggered at Enter time by an
# PSReadLine key handler that rewrites the buffer using PowerShell's tokenizer,
# so strings / parameters / sub-expressions are left alone.
#
# The pipeline filter functions G/H/T/L themselves are defined in 99-functions.ps1.

if (-not (Get-Module -ListAvailable -Name PSReadLine)) {
    return
}

Set-PSReadLineKeyHandler -Key Enter -BriefDescription 'AcceptLineWithPipelineGlobals' -LongDescription 'Rewrite bareword G/H/T/L tokens in argument position into pipeline filters before accepting the line' -ScriptBlock {
    param($key, $arg)

    # The set of letters we treat as zsh-style global aliases.
    $globals = @{
        'G' = $true
        'H' = $true
        'T' = $true
        'L' = $true
    }

    # Token kinds where the *next* bareword is in COMMAND position, so we must
    # NOT insert a pipe before it. Anything else means the bareword is being
    # used as an argument and we should rewrite.
    $commandPositionKinds = @(
        'NewLine', 'EndOfInput', 'Semi', 'Pipe',
        'AndAnd', 'OrOr',
        'LParen', 'LCurly', 'AtParen', 'AtCurly', 'DollarParen',
        'Equals', 'PlusEquals', 'MinusEquals', 'MultiplyEquals', 'DivideEquals', 'RemainderEquals',
        'Ampersand', 'Dot'
    )

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ([string]::IsNullOrWhiteSpace($line)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        return
    }

    $tokens = $null
    $errors = $null
    try {
        [void][System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$tokens, [ref]$errors)
    } catch {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        return
    }

    if (-not $tokens -or $tokens.Count -lt 2) {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        return
    }

    # Collect offsets where we need to insert "| ".
    $insertOffsets = New-Object System.Collections.Generic.List[int]
    for ($i = 1; $i -lt $tokens.Count; $i++) {
        $tok = $tokens[$i]
        $kind = [string]$tok.Kind
        if ($kind -ne 'Generic' -and $kind -ne 'Identifier') { continue }
        if (-not $globals.ContainsKey($tok.Text)) { continue }

        $prev = $tokens[$i - 1]
        if ($commandPositionKinds -contains [string]$prev.Kind) { continue }

        $insertOffsets.Add($tok.Extent.StartOffset)
    }

    if ($insertOffsets.Count -eq 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        return
    }

    # Insert from the end so earlier offsets stay valid.
    $newLine = $line
    for ($i = $insertOffsets.Count - 1; $i -ge 0; $i--) {
        $off = $insertOffsets[$i]
        $newLine = $newLine.Substring(0, $off) + '| ' + $newLine.Substring($off)
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $newLine)
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
