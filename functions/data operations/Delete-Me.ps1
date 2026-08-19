function Delete-Me {
    $scriptPath = $MyInvocation.MyCommand.Path
    if (Test-Path -LiteralPath $scriptPath) {
        Remove-Item -LiteralPath $scriptPath -Force
        Write-Host "Script '$scriptPath' has been deleted." -ForegroundColor Green
    } else {
        Write-Host "Script '$scriptPath' not found." -ForegroundColor Yellow
    }
}