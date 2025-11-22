function Get-WSLArgumentValue ($argumentName, $argumentValuePartial) {
    if ($flags[$argumentName].completionFunction) {
        &$flags[$argumentName].completionFunction -partial $argumentValuePartial
    }
}
# vim: ts=2 sts=2 sw=2 et
