
$etlFile = "C:\CollectSigninPerformanceData\Crd.etl"
$TraceName = "CollectSigninPerformanceData"

$folder = "C:\CollectSigninPerformanceData"
if (-not (Test-Path -Path $folder)) {
    New-Item -Path $folder -ItemType Directory | Out-Null
}


if ( -not [System.Diagnostics.EventLog]::SourceExists('SigninPerformanceData') )
{
    New-EventLog -LogName Application -Source 'SigninPerformanceData'
    Write-EventLog -LogName Application `
        -Source "SigninPerformanceData" `
        -EntryType Information `
        -EventId 0 `
        -Message "SigninPerformanceData provider added." 
}

logman start "$TraceName" -ow -o $etlFile -nb 16 16 -bs 1024 -mode Circular -f bincirc -max 8 -ets
logman update trace "$TraceName" -p "{4F7C073A-65BF-5045-7651-CC53BB272DB5}" "0xffffffffffffffff" "0xff" -ets

if ($LASTEXITCODE -eq 0) {
    Write-EventLog -LogName Application `
        -Source "SigninPerformanceData" `
        -EntryType Information `
        -EventId 1 `
        -Message "$TraceName trace started." 
} else {
    Write-EventLog -LogName Application `
        -Source "SigninPerformanceData" `
        -EntryType Error `
        -EventId 1 `
        -Message "$TraceName cannot started correctly."
} 