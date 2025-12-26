

$etlFile = "C:\temp\Crd.etl"
$TraceName = "CollectSigninPerformanceData"

# Stop the trace
logman stop "$TraceName" -ets 

Start-Sleep 2

# Convert the trace
tracerpt.exe $etlFile -o "$etlFile.csv" -of CSV -en ANSI -y

Start-Sleep 2

# Import the trace as CSV
$csv = Import-Csv -Path "$etlFile.csv"
# Get the ref time at which the user dismisses the lock screen 
$refStartSigninRow = $csv | Sort-Object "Clock-Time" -Descending | Where-Object { $_."Event Name" -in @("CLogonController_WaitForLockScreenDismiss_Activity","CLockAction__SuspendOrResumeLockAppShownWatchdogTimer_Activity") } | Select-Object -First 1
$refStartSigninTimeEvent = [string] $refStartSigninRow."Event Name"
$refStartSigninTime = [DateTime]::FromFileTimeUtc($refStartSigninRow.'Clock-Time')
$refStartSigninTimeTS = $refStartSigninTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")


# Get the ref time at which the user session becomes active
$lastSigninEvent = Get-WinEvent `
    -LogName "Security" `
    -FilterXPath "*[System[(EventID=4624 and TimeCreated[@SystemTime>='$refStartSigninTimeTS'])] and EventData[Data[@Name='LogonType']='2' or Data[@Name='LogonType']='7' or Data[@Name='LogonType']='11']]" `
    -MaxEvents 1 `
    -Oldest

$lastSigninEventTime = $lastSigninEvent.TimeCreated.ToUniversalTime()
$lastSigninEventTimeTS = $lastSigninEventTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
$lastSigninEventSID = $lastSigninEvent.Properties[4].Value.value
$lastSigninEventsUPN = $lastSigninEvent.Properties[5].Value
$lastSigninEventsLogonType = $lastSigninEvent.Properties[8].Value

$LogonTypeMapping = @{
    2 = "Interactive"
    7 = "Unlock"
    11 = "CachedInteractive"
}


# Get the info about the last credential provider used during sign-in
$regLogonUI = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
$GUIDProvidersMapping = @{
    "{1b283861-754f-4022-ad47-a5eaaa618894}" = "Smartcard Reader Selection Provider"
    "{1ee7337f-85ac-45e2-a23c-37c753209769}" = "Smartcard WinRT Provider"
    "{2135f72a-90b5-4ed3-a7f1-8bb705ac276a}" = "PicturePasswordLogonProvider"
    "{25CBB996-92ED-457e-B28C-4774084BD562}" = "GenericProvider"
    "{27FBDB57-B613-4AF2-9D7E-4FA7A66C21AD}" = "TrustedSignal Credential Provider"
    "{3dd6bec0-8193-4ffe-ae25-e08e39ea4063}" = "NPProvider"
    "{48B4E58D-2791-456C-9091-D524C6C706F2}" = "Secondary Authentication Factor Credential Provider"
    "{600e7adb-da3e-41a4-9225-3c0399e88c0c}" = "CngCredUICredentialProvider"
    "{60b78e88-ead8-445c-9cfd-0b87f74ea6cd}" = "PasswordProvider"
    "{8AF662BF-65A0-4D0A-A540-A338A999D36F}" = "FaceCredentialProvider"
    "{8FD7E19C-3BF7-489B-A72C-846AB3678C96}" = "Smartcard Credential Provider"
    "{94596c7e-3744-41ce-893e-bbf09122f76a}" = "Smartcard Pin Provider"
    "{BEC09223-B018-416D-A0AC-523971B639F5}" = "WinBio Credential Provider"
    "{C5D7540A-CD51-453B-B22B-05305BA03F07}" = "Cloud Experience Credential Provider"
    "{cb82ea12-9f71-446d-89e1-8d0924e1256e}" = "PINLogonProvider"
    "{D6886603-9D2F-4EB2-B667-1971041FA96B}" = "NGC Credential Provider"
    "{e74e57b0-6c6d-44d5-9cda-fb2df5ed7435}" = "CertCredProvider"
    "{f64945df-4fa9-4068-a2fb-61af319edd33}" = "RdpCredentialProvider"
    "{F8A0B131-5F68-486c-8040-7E8FC3C85BB6}" = "WLIDCredentialProvider"
    "{F8A1793B-7873-4046-B2A7-1F318747F427}" = "FIDO Credential Provider"
}

$eventPaylod = @{
    "refStartSigninTimeUtc" = $refStartSigninTimeTS
    "refStartSigninTimeEvent" = $refStartSigninTimeEvent
    "SigninDurationMs" = [string] ($lastSigninEventTime - $refStartSigninTime).TotalMilliseconds
    "SigninEventTimeUtc" = $lastSigninEventTimeTS
    "SigninEventSID" = $lastSigninEventSID
    "SigninEventUPN" = $lastSigninEventsUPN
    "SigninEventLogonType" = $LogonTypeMapping[ [int] $lastSigninEventsLogonType]
    "CredentialProviderGUID" = $regLogonUI.LastLoggedOnProvider
    "CredentialProviderName" = $GUIDProvidersMapping[ [string] $regLogonUI.LastLoggedOnProvider]
    "CredentialProviderUserSID" = $regLogonUI.LastLoggedOnUserSID
}

Write-EventLog -LogName Application `
    -Source "SigninPerformanceData" `
    -EntryType Information `
    -EventId 2 `
    -Message ( $eventPaylod | ConvertTo-Json )

# Start the trace again

logman start "$TraceName" -ow -o $etlFile -nb 16 16 -bs 1024 -mode Circular -f bincirc -max 8 -ets
logman update trace "$TraceName" -p "{4F7C073A-65BF-5045-7651-CC53BB272DB5}" "0xffffffffffffffff" "0xff" -ets
