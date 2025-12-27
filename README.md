## SigninPerformanceData

This Proof of Concept measures the time it takes for a user to sign in, starting from their first interaction with the Windows logon screen until successful authentication. The goal is to capture the end‑to‑end duration of the sign‑in process and compare average times across different credential providers such as password, PIN, and Windows Hello biometrics. These measurements help quantify productivity gains offered by faster, modern authentication methods.

The solution consists of two PowerShell scripts executed by two scheduled tasks: one triggered at system startup and the other triggered upon successful sign‑in. The sign‑in task generates an Application event containing the collected timing statistics.

### Detailed architecture

The first scheduled task runs at startup. It does the following:
1. If the `C:\CollectSigninPerformanceData` does not exist, it creates it. That is where the scripts and the ETL traces will be saved.
2. If the `SigninPerformanceData` provider doesn't exist, it creates it. The solution uses the `Application` eventlog to generate events with statistics.
3. Starts and update an ETL trace for the provider `{4F7C073A-65BF-5045-7651-CC53BB272DB5}`. It uses `logman.exe`.

Then at user logon and worksation unlock, the second scheduled task starts. It does the following:
1. It stops the ETL trace using `logman.exe`.
2. It convert it into a CSV file in the same folder using `tracerpt.exe`.
3. It extract the time at which the credential providers are proposed for authentication from the trace.
4. It looks for the succesful sign-in time in the `Security` eventlog.
5. It extracts the credential provider used for the signin from the registry key `LogonUI`.
6. It generates the event 2 in the `Application` eventlog with the statistics for the signin.
7. It restart the ETL trace using `logman.exe`.


### Installation

Register the first scheduled task `Set-SigninPerformanceData`:
```PowerShell
Register-ScheduledTask -Xml (Get-Content -Path "Set-SigninPerformanceData.xml" -Raw)
```

Register the seconf scheduled task `Get-SigninPerformanceData`:
```PowerShell
Register-ScheduledTask -Xml (Get-Content -Path "Get-SigninPerformanceData.xml" -Raw)
```

### Events

The solution registers and uses its own provider called `SigninPerformanceData` logging in the `Application` eventlog. Here is the list of event it generates. 

|Source|Event ID|Level|Description|
|-|-|-|-|
|`SigninPerformanceData`|0|Information|Provider is registered succesfully|
|`SigninPerformanceData`|1|Information|The ETL trace has started (it should happen during system boot)|
|`SigninPerformanceData`|1|Error|The ETL trace did not start|
|`SigninPerformanceData`|2|Information|It contains the statistics of the signin|

Example of event 2 with statistics:
```json
{
    "SigninEventTimeUtc":  "2025-12-27T00:09:19.6006947Z",
    "SigninEventUPN":  "johndo@contoso.com",
    "SigninEventLogonType":  "CachedInteractive",
    "CredentialProviderUserSID":  "S-1-12-1-3115205842-1258247004-421483497-897123921",
    "SigninDurationMs":  "725.832",
    "CredentialProviderName":  "FaceCredentialProvider",
    "refStartSigninTimeUtc":  "2025-12-27T00:09:18.8748627Z",
    "refStartSigninTimeEvent":  "CLogonController_WaitForLockScreenDismiss_Activity",
    "SigninEventSID":  "S-1-12-1-3115205842-1258247004-421483497-897123921",
    "CredentialProviderGUID":  "{8AF662BF-65A0-4D0A-A540-A338A999D36F}"
}
```

### Security considerations

As the scheduled tasks run as `SYSTEM` it is important to keep the scripts in a path where only local administrators have access.