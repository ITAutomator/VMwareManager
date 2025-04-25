<#

VMWare Manager

This script reports or updates vmware ESXi hosts and VMs.

https://github.com/ITAutomator/MerakiWifiManager
https://www.itautomator.com

#>
######################
## Main Procedure
######################
###
## To enable scrips, Run powershell 'as admin' then type
## Set-ExecutionPolicy Unrestricted
###
### Main function header - Put ITAutomator.psm1 in same folder as script
$scriptFullname = $PSCommandPath ; if (!($scriptFullname)) {$scriptFullname =$MyInvocation.InvocationName }
$scriptXML      = $scriptFullname.Substring(0, $scriptFullname.LastIndexOf('.'))+ ".xml"  ### replace .ps1 with .xml
$scriptDir      = Split-Path -Path $scriptFullname -Parent
$scriptName     = Split-Path -Path $scriptFullname -Leaf
$scriptBase     = $scriptName.Substring(0, $scriptName.LastIndexOf('.'))
$scriptVer      = "v"+(Get-Item $scriptFullname).LastWriteTime.ToString("yyyy-MM-dd")
$psm1="$($scriptDir)\ITAutomator.psm1";if ((Test-Path $psm1)) {Import-Module $psm1 -Force} else {write-output "Err 99: Couldn't find '$(Split-Path $psm1 -Leaf)'";Start-Sleep -Seconds 10;Exit(99)}
# Get-Command -module ITAutomator  ##Shows a list of available functions
#region Transcript Open
$Transcript = [System.IO.Path]::GetTempFileName()               
Start-Transcript -path $Transcript | Out-Null
#endregion Transcript Open
######################
Write-Host "-----------------------------------------------------------------------------"
Write-Host "$($scriptName) $($scriptVer)       User:$($env:computername)\$($env:username) PSver:$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
Write-Host ""
Write-Host "This script reports or updates vmware ESXi hosts and VMs."
Write-Host ""
# Module PowerCLI present
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Write-Host "VMware.PowerCLI not found. Use ModuleManager to install." -ForegroundColor Yellow
    Write-Host "(or to add manaully as admin: Install-Module -Name VMware.PowerCLI -Scope AllUsers)"
    PressEnterToContinue
    exit
}
Write-Host "Importing VMware.PowerCLI module (may take a few mins)..." -ForegroundColor Yellow
Import-Module VMware.PowerCLI
# Set PowerCLI configuration to ignore invalid certificates and set default server mode
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$false| Out-Null
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP:$false -confirm:$false | Out-Null
# Get input file path
$csvInputPath    = Join-Path -Path $scriptDir -ChildPath 'Esxi Servers to Inventory.csv'
Do { # action
    Write-Host "--------------- Choices ------------------"
    Write-Host "Esxi Servers: " -NoNewline
    Write-Host (Split-Path $csvInputPath -Leaf) -ForegroundColor Green
    Write-Host "     Entries: " -NoNewline
    if (Test-Path $csvInputPath) {
        Write-Host (Import-Csv $csvInputPath).Count -ForegroundColor Green
    } else {
        Write-Host "<file not found, choose R to create a template file>" -ForegroundColor Yellow
    }
    Write-Host "[R] Report VM Guest Inventory to a new CSV file"
    Write-Host "[A] Add an admin user to selected VMs"
    Write-Host "[X] Exit"
    Write-Host "------------------------------------------"
    $choice = PromptForString "Choice [blank to exit]"
    if (($choice -eq "") -or ($choice -eq "X")) {
        Break
    } # Exit
    if ($choice -in @("R","A")) { # report, add
        $DateSnap        = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
        # ----------------------------
        # Import ESXi host list. CSV headers must include: ServerName,IPAddress
        # ----------------------------
        if (-not (Test-Path $csvInputPath)) {
            Write-Host "Creating template CSV file: " -NoNewline
            Write-Host (Split-Path $csvInputPath -Leaf) -ForegroundColor Yellow
            PressEnterToContinue "Press Enter to edit the template CSV file"
            $lines=@()
            $lines += "ServerName,IPAddress,Misc1,Misc2"
            $lines += "esxihost1,192.168.75.16,Notes about this server,Misc etc columns are ignored"
            $lines += "esxihost1,192.168.75.16,,"
            ForEach ($line in $lines) {
                Add-Content -Path $csvInputPath -Value $line
            } # each line
            Start-Process $csvInputPath
            PressEnterToContinue "Press Enter when done editing the CSV file"
        }
        $servers = Import-Csv -Path $csvInputPath
        # ----------------------------
        # Show server list
        # ----------------------------
        # $i=0
        # Write-Host "Choose from the following ESXi hosts:" -ForegroundColor Yellow
        # $servers | ForEach-Object { Write-Host " $((++$i)) $($_.ServerName) [$($_.IPAddress)] Status: $($_.Status)" }
        Write-host "ESXi hosts in the CSV file: " -noNewline
        Write-Host $servers.Count -ForegroundColor Yellow
        Write-Host "Choose from the popup list (may be behind this window - check taskbar): " -NoNewline
        $msg= "Select rows and click OK (Use Ctrl and Shift and Filter features to multi-select)"
        $servers =  @($servers | Out-GridView -PassThru -Title $msg)
        if ($servers.Count -eq 0) {
            Write-Host "Canceled"
            Continue
        } # canceled
        $i=0
        Write-Host "Choose from the following ESXi hosts:" -ForegroundColor Yellow
        $servers | ForEach-Object { Write-Host " $((++$i)) $($_.ServerName) [$($_.IPAddress)]" }
        # ----------------------------
        # Prompt for credentials
        # ----------------------------
        if ($null -eq $cred) {
            Write-Host "Please enter your ESXi credentials:" -ForegroundColor Yellow
            $cred = Get-Credential -Message "Enter your ESXi/root credentials"
        }
        else {
            $pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password))
            Write-Host "Existing credentials: " -NoNewline
            Write-Host "$($cred.UserName), "  -NoNewline -ForegroundColor Green
            Write-Host "$($pw.Substring(0,[Math]::Min(3, $pw.Length)))$("*".Padright($pw.length-3,"*"))" -ForegroundColor Green
            if (-not (AskForChoice "Use these credentials?")) {
                $cred = Get-Credential -Message "Enter your ESXi/root credentials"
            }
        }
        # ----------------------------
        # Loop through each ESXi host and collect VMs
        # ----------------------------
        $servers_count = $servers.Count
        $servers_i = 0
        $objCSVRows = @()
        foreach ($srv in $servers) {
            Write-Host "ESXi $((++$servers_i)) of $($servers_count): $($srv.ServerName) [$($srv.IPAddress)] ... " -ForegroundColor Magenta -NoNewline
            if ($null -eq $srv.IPAddress) {
                Write-Host "ERROR: No IP address found" -ForegroundColor Red
                continue
            }
            try {
                Disconnect-VIServer -Force -Confirm:$false -ErrorAction Ignore | Out-Null
                $viServer = Connect-VIServer -Server $srv.IPAddress -Credential $cred -ErrorAction Stop
                Write-Host "OK" -ForegroundColor Green
            }
            catch {
                Write-Host "ERROR" -ForegroundColor Red
                Write-Warning "Failed to connect to $($srv.ServerName): $_"
                continue
            }
            if ($choice -in @("R")) { # report
                $vms = Get-VM -Server $viServer 
                $vm_count = $vms.Count
                $vm_i = 0
                ForEach ($vm in $vms) {
                    Write-Host " VM $((++$vm_i)) of $($vm_count): $($vm.Name) OS: $($vm.Guest.OSFullName)"
                    $disks = $vm.Guest.Disks | Sort-Object Path | ForEach-Object {Write-Output "$($_.Path) using $([int]($_.CapacityGB-$_.FreeSpaceGB)) of $([int]$_.CapacityGB) GB"}
                    $objCSVRows += [pscustomobject]@{
                        DateSnap           = $DateSnap
                        ServerName         = $srv.ServerName
                        ServerIP           = $srv.IPAddress
                        ServerVersion      = $viServer.Version
                        VMName             = $vm.Name
                        PowerState         = $vm.PowerState
                        Notes              = $vm.Notes
                        GuestHostName      = $vm.Guest.HostName
                        GuestVM            = $vm.Guest.VM
                        GuestOSFullName    = $vm.Guest.OSFullName
                        GuestIPAddress     = $vm.Guest.IPAddress[0]
                        GuestState         = $vm.Guest.State
                        NumCpu             = $vm.NumCpu
                        MemoryGB           = $vm.MemoryGB
                        UsedSpaceGB        = [int]$vm.UsedSpaceGB
                        ProvisionedSpaceGB = [int]$vm.ProvisionedSpaceGB
                        GuestDisks         = $disks -join ", "
                    } # object
                } # foreach vm
            } # report
            if ($choice -in @("A")) { # add admin user
                # Get AdminUsername from user
                if ($AdminUsername -and ($servers_i -eq 1)) {
                    Write-Host "New User name [to create]: " -NoNewline
                    Write-Host $AdminUsername -ForegroundColor Green
                    if (-not (AskForChoice "Use this New User name [to create]?")) {
                        $AdminUsername = $null
                    }
                } # re-use existing user name
                if ($null -eq $AdminUsername) {
                    $AdminUsername   = Read-Host -Prompt "Enter new admin user name (eg: 'admin1')"
                    $securePwd = Read-Host -Prompt "Enter password for '$AdminUsername'" -AsSecureString
                    # Convert SecureString to plain text for New-VMHostAccount
                    $AdminPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd))
                }
                # check for existing user account
                $accounts = Get-VMHostAccount -Server $srv.IPAddress
                $accounts_i = 0
                $accounts | ForEach-Object { Write-Host "   $((++$accounts_i)) $($_.Name) [$($_.Description)]" }
                Write-Host "  Adding User "-NoNewline
                Write-Host $AdminUsername -foregroundcolor Magenta -NoNewline
                $account =  $accounts | Where-Object {$_.Id -eq $AdminUsername} | Select-Object -First 1
                # contentReference[oaicite:0]{index=0}
                if ($account) {
                    Write-Host " OK: already exists" -ForegroundColor Green
                } # user exists
                else {
                    try {
                        $result = New-VMHostAccount -Server $srv.IPAddress `
                        -Id           $AdminUsername `
                        -Password     $AdminPwd `
                        -UserAccount  `
                        -Description  "Admin created by $($env:computername)\$($env:username) on $(Get-Date -format "yyyy-MM-dd")"
                    }
                    catch {
                        $warning = $_
                        Write-Host " "
                        Write-Warning "New-VMHostAccount Failed: $_"
                        PressEnterToContinue
                        continue
                    }
                    if ($result) {
                        Write-Host " OK: created" -ForegroundColor Yellow
                    } # user created
                    else {
                        Write-Host " ERR: Failed to create" -ForegroundColor Red
                    } # failed to create user
                } # user does not exist
                Write-Host "  Adding User "-NoNewline
                Write-Host $AdminUsername -foregroundcolor Magenta -NoNewline
                Write-Host " with Permission "-NoNewline
                Write-Host "Admin" -foregroundcolor Magenta -NoNewline
                # Set up for using Get-EsxCli commands
                $vmhost = Get-VMHost -Server $srv.IPAddress
                $esxcli = Get-EsxCli -VMHost $vmhost -V2
                # Check if user is already in the Admin group
                $check = $esxcli.system.permission.list.Invoke() | Where-Object Principal -EQ $AdminUsername | Where-Object Role -EQ "Admin"| Select-Object -First 1
                if ($check) {
                    Write-Host " OK: already Admin" -ForegroundColor Green
                } else { # user not admin
                    # esxcli.system.permission set
                    try {
                        $permArgs = $esxcli.system.permission.set.CreateArgs()
                        $permArgs.id   = $AdminUsername
                        $permArgs.role = "Admin"        # must be exactly Admin, ReadOnly or NoAccess 
                        $permArgs.group  = $false       # ensure this is treated as a user, not a group
                        $result = $esxcli.system.permission.set.Invoke($permArgs)
                    }
                    catch {
                        $warning = $_
                        Write-Host " "
                        Write-Warning "esxcli.system.permission Failed: $_"
                        PressEnterToContinue
                        continue
                    }
                    # esxcli.system.permission result
                    if ($result) {
                        Write-Host " OK: Added" -ForegroundColor Yellow
                    } # user added to admin group
                    else {
                        Write-Host " ERR: Failed to add user to admin group" -ForegroundColor Red
                    } # failed to add user to admin group                    
                } # user not admin
            } # add admin user
            # ----------------------------
            Disconnect-VIServer -Force -Confirm:$false -ErrorAction Ignore | Out-Null
        }
        if ($choice -in @("R")) { # report
            # ----------------------------
            # Export the consolidated list
            # ----------------------------
            $csvOutputPath   = Join-Path -Path $scriptDir -ChildPath "Esxi Report $($DateSnap).csv"
            $objCSVRows | Export-Csv -Path $csvOutputPath -NoTypeInformation
            Write-Host "Output CSV: $(split-path $csvOutputPath -Leaf)" -ForegroundColor Green
            If (askForChoice "Open CSV now?") {
                Start-Process $csvOutputPath
            }
        } # report
    } # report, admin
    Write-Host "Done"
    Start-sleep 2
} While ($true) # loop until Break 
#region Transcript Save
Stop-Transcript | Out-Null
$TranscriptTarget = "$($scriptDir)\Logs\$($scriptBase)_$(Get-Date -format "yyyy-MM-dd HH-mm-ss")_transcript.txt"
New-Item -Path (Split-path $TranscriptTarget -Parent) -ItemType Directory -Force | Out-Null
If (Test-Path $TranscriptTarget) {Remove-Item $TranscriptTarget -Force}
Move-Item $Transcript $TranscriptTarget -Force
Write-Host "Exited. Transcript saved to: $(Split-path $TranscriptTarget -Leaf)"
#endregion Transcript Save