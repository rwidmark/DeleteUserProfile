Function New-RSReturnMessage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify if the operation result is a success or an error.")]
        [ValidateSet("Success", "Error")]
        [string]$ReturnType,
        [Parameter(Mandatory = $true, HelpMessage = "Specify the message that should be returned to the caller.")]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    process {
        [PSCustomObject]@{
            ReturnCode = if ($ReturnType -eq "Success") { 0 } else { 1 }
            ReturnType = $ReturnType
            Message    = $Message
        }
    }
}

Function Get-RSProfileUserName {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the profile path to resolve the user name from.")]
        [ValidateNotNullOrEmpty()]
        [string]$LocalPath
    )

    process {
        Split-Path -Path $LocalPath -Leaf
    }
}

Function Get-RSProfileLookup {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the profile collection that should be indexed by user name.")]
        [ValidateNotNull()]
        $ProfileData
    )

    process {
        $profileLookup = @{}

        foreach ($profile in @($ProfileData)) {
            if ($null -eq $profile.LocalPath) {
                continue
            }

            $userName = Get-RSProfileUserName -LocalPath $profile.LocalPath

            if (-not [string]::IsNullOrWhiteSpace($userName)) {
                $profileLookup[$userName] = $profile
            }
        }

        $profileLookup
    }
}

Function Get-RSUserProfileInventory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the computer name that should be queried for user profiles.")]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName
    )

    process {
        $cimSession = $null

        try {
            Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
            $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop

            @(Get-CimInstance -CimSession $cimSession -ClassName Win32_UserProfile -ErrorAction Stop | Where-Object { -not $_.Special })
        }
        finally {
            if ($null -ne $cimSession) {
                $cimSession | Remove-CimSession -ErrorAction SilentlyContinue
            }
        }
    }
}

Function Get-RSUserProfile {
    <#
        .SYNOPSIS
        Return all user profiles that are saved on a computer.

        .DESCRIPTION
        Return all user profiles that are saved on a local or remote computer and you can also delete one or all of the user profiles, the special windows profiles are excluded.
        You can also show all user profiles from multiple computers at the same time.

        .PARAMETER ComputerName
        The name of the remote computer you want to display all of the user profiles from. If you want to use it on a local computer you don't need to fill this one out.
        You can add multiple computers like this: -ComputerName "Win11-Test", "Win10"

        .EXAMPLE
        Get-RSUserProfile
        # This will return all of the user profiles saved on the local machine

        .EXAMPLE
        Get-RSUserProfile -ComputerName "Win11-Test"
        # This will return all of the user profiles saved on the remote computer "Win11-test"

        .EXAMPLE
        Get-RSUserProfile -ComputerName "Win11-Test", "Win10"
        # This will return all of the user profiles saved on the remote computers named Win11-Test and Win10

        .LINK
        https://github.com/rwidmark/DeleteUserProfile/blob/main/README.md

        .NOTES
        Author:         Robin Widmark
        Mail:           robin@widmark.dev
        Website/Blog:   https://widmark.dev
        X:              https://x.com/widmark_robin
        Mastodon:       https://mastodon.social/@rwidmark
        YouTube:        https://www.youtube.com/@rwidmark
        Linkedin:       https://www.linkedin.com/in/rwidmark/
        GitHub:         https://github.com/rwidmark
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "Enter one or more computer names to collect user profiles from.")]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = "localhost"
    )

    begin {
        $jobGetProfile = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($currentComputer in ($ComputerName | Sort-Object -Unique)) {
            Write-Verbose "Starting user profile lookup on $currentComputer"

            $job = Start-ThreadJob -Name $currentComputer -ThrottleLimit 50 -ArgumentList $currentComputer, $VerbosePreference -ScriptBlock {
                param(
                    [string]$ComputerName,
                    [System.Management.Automation.ActionPreference]$PassedVerbosePreference
                )

                $VerbosePreference = $PassedVerbosePreference
                $cimSession = $null

                try {
                    $currentDate = Get-Date
                    Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
                    $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop
                    $getUserData = @(Get-CimInstance -CimSession $cimSession -ClassName Win32_UserProfile -ErrorAction Stop |
                        Where-Object { -not $_.Special } |
                        Sort-Object -Descending -Property LastUseTime)

                    if ($getUserData.Count -eq 0) {
                        Write-Verbose "No user profiles found on $ComputerName"
                        return
                    }

                    foreach ($profile in $getUserData) {
                        $notUsedFor = $null

                        if ($null -ne $profile.LastUseTime) {
                            $timeSpan = New-TimeSpan -Start $profile.LastUseTime -End $currentDate
                            $notUsedFor = [ordered]@{}

                            if ($timeSpan.Days -gt 0) {
                                $notUsedFor.days = [string]$timeSpan.Days
                            }
                            if ($timeSpan.Hours -gt 0) {
                                $notUsedFor.hours = [string]$timeSpan.Hours
                            }
                            if ($timeSpan.Minutes -gt 0) {
                                $notUsedFor.minutes = [string]$timeSpan.Minutes
                            }
                            if ($notUsedFor.Count -eq 0) {
                                $notUsedFor.minutes = "0"
                            }
                        }

                        [PSCustomObject]@{
                            Computer  = $ComputerName
                            UserName  = if ($null -ne $profile.LocalPath) { Split-Path -Path $profile.LocalPath -Leaf }
                            LocalPath = $profile.LocalPath
                            LastUsed  = if ($null -ne $profile.LastUseTime) { ([datetime]$profile.LastUseTime).ToString("yyyy-MM-dd HH:mm") }
                            Loaded    = $profile.Loaded
                            NotUsed   = if ($null -ne $notUsedFor) { $notUsedFor } else { "N/A" }
                        }
                    }
                }
                catch {
                    Write-Error "${ComputerName}: $($PSItem.Exception.Message)"
                }
                finally {
                    if ($null -ne $cimSession) {
                        $cimSession | Remove-CimSession -ErrorAction SilentlyContinue
                    }
                }
            }

            [void]$jobGetProfile.Add($job)
        }
    }

    end {
        if ($jobGetProfile.Count -eq 0) {
            return
        }

        try {
            Write-Verbose "Waiting for $($jobGetProfile.Count) user profile lookup job(s) to complete"
            Receive-Job -Job $jobGetProfile -AutoRemoveJob -Wait -ErrorAction Stop
        }
        catch {
            Write-Error $PSItem.Exception.Message
        }
    }
}

Function Remove-RSUserProfile {
    <#
        .SYNOPSIS
        Let you delete user profiles from a local or remote computer

        .DESCRIPTION
        Let you delete user profiles from a local computer or remote computer, you can also delete all of the user profiles. You can also exclude profiles.
        If the profile are loaded you can't delete it. The special Windows profiles are excluded

        .PARAMETER ComputerName
        The name of the remote computer you want to display all of the user profiles from. If you want to use it on a local computer you don't need to fill this one out.

        .PARAMETER UserName
        If you want to delete specific user profiles you can enter the username here.

        .PARAMETER Exclude
        This parameter only works if -All are used, here you can enter usernames that you want to exclude from the deletion.

        .PARAMETER All
        If you want to delete all of the user profiles on the local or remote computer you can use this switch

        .EXAMPLE
        Remove-RSUserProfile -All
        # This will delete all of the user profiles from the local computer your running the script from. Beside special and loaded profiles

        .EXAMPLE
        Remove-RSUserProfile -Exclude "User1", "User2" -All
        # This will delete all of the user profiles except user profile User1 and User2 on the local computer

        .EXAMPLE
        Remove-RSUserProfile -UserName "User1", "User2"
        # This will delete only user profile "User1" and "User2" from the local computer where you run the script from if the profile are not loaded.

        .EXAMPLE
        Remove-RSUserProfile -ComputerName "Win11-test" -All
        # This will delete all of the user profiles that are not special or loaded on the remote computer named "Win11-Test"

        .EXAMPLE
        Remove-RSUserProfile -ComputerName "Win11-test" -Exclude "User1", "User2" -All
        # This will delete all of the user profiles except user profile User1 and User2 on the remote computer named "Win11-Test" if the profile are not loaded

        .EXAMPLE
        Remove-RSUserProfile -ComputerName "Win11-test" -UserName "User1", "User2"
        # This will delete only user profile "User1" and "User2" from the remote computer named "Win11-Test" if the profile are not loaded

        .EXAMPLE
        Remove-RSUserProfile -UserName "User1" -WhatIf
        # This will show what would be removed without deleting the profile

        .LINK
        https://github.com/rwidmark/DeleteUserProfile/blob/main/README.md

        .NOTES
        Author:         Robin Widmark
        Mail:           robin@widmark.dev
        Website/Blog:   https://widmark.dev
        X:              https://x.com/widmark_robin
        Mastodon:       https://mastodon.social/@rwidmark
        YouTube:        https://www.youtube.com/@rwidmark
        Linkedin:       https://www.linkedin.com/in/rwidmark/
        GitHub:         https://github.com/rwidmark
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High", DefaultParameterSetName = "ByUserName")]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "Enter the computer name that you want to delete user profiles from.")]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = "localhost",
        [Parameter(Mandatory = $true, ParameterSetName = 'ByUserName', HelpMessage = "Enter one or more user profile names that you want to delete.")]
        [ValidateNotNullOrEmpty()]
        [string[]]$UserName,
        [Parameter(Mandatory = $true, ParameterSetName = 'AllProfiles', HelpMessage = "Use this switch if you want to delete all removable user profiles on the computer.")]
        [switch]$All,
        [Parameter(Mandatory = $false, ParameterSetName = 'AllProfiles', HelpMessage = "Enter one or more user profile names that should be excluded when -All is used.")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Exclude
    )

    begin {
        $jobReturnMessage = [System.Collections.Generic.List[string]]::new()
    }

    process {
        Write-Verbose "Collecting user profiles from $ComputerName"

        try {
            $getAllProfiles = Get-RSUserProfileInventory -ComputerName $ComputerName
        }
        catch {
            Write-Error "Failed to retrieve user profiles from ${ComputerName}: $($PSItem.Exception.Message)"
            return
        }

        if ($getAllProfiles.Count -eq 0) {
            Write-Verbose "No removable user profiles were found on $ComputerName"
            return
        }

        # Build a lookup table once so validation and deletion stay fast even with many profiles.
        $profileLookup = Get-RSProfileLookup -ProfileData $getAllProfiles
        $targetUsers = if ($All) { $profileLookup.Keys | Sort-Object } else { $UserName | Sort-Object -Unique }

        foreach ($profileName in $targetUsers) {
            $checkProfile = Confirm-RSProfile -UserName $profileName -ProfileData $profileLookup -Exclude $Exclude

            if ($checkProfile.ReturnCode -ne 0) {
                [void]$jobReturnMessage.Add($checkProfile.Message)
                continue
            }

            $target = "$ComputerName\$profileName"

            if (-not $PSCmdlet.ShouldProcess($target, "Remove user profile")) {
                continue
            }

            try {
                # Delete in-process so WhatIf/Confirm/Verbose behave consistently and avoid per-profile job overhead.
                Write-Verbose "Removing user profile $profileName from $ComputerName"
                $profileLookup[$profileName] | Remove-CimInstance -ErrorAction Stop
                Write-Verbose "User profile $profileName was removed from $ComputerName"
            }
            catch {
                Write-Error "${profileName}: $($PSItem.Exception.Message)"
            }
        }
    }

    end {
        if ($jobReturnMessage.Count -gt 0) {
            $jobReturnMessage
        }
    }
}

Function Confirm-RSProfile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Enter the user profile name that you want to verify.")]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,
        [Parameter(Mandatory = $true, HelpMessage = "Provide the profile collection or lookup table that should be searched.")]
        [ValidateNotNull()]
        $ProfileData,
        [Parameter(Mandatory = $false, HelpMessage = "Enter one or more user profile names that should be excluded from deletion.")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Exclude
    )

    process {
        # Keep supporting both raw profile collections and lookup tables for direct callers of Confirm-RSProfile.
        $checkExists = if ($ProfileData -is [System.Collections.IDictionary]) {
            $ProfileData[$UserName]
        }
        else {
            $ProfileData |
                Where-Object { $null -ne $_.LocalPath -and (Get-RSProfileUserName -LocalPath $_.LocalPath) -eq $UserName } |
                Select-Object -First 1
        }

        $checkExclude = $null -ne $Exclude -and $Exclude -contains $UserName

        if ($null -ne $checkExists -and -not $checkExclude) {
            if ($checkExists.Loaded) {
                New-RSReturnMessage -ReturnType Error -Message "User profile $UserName is loaded and cannot be removed"
            }
            else {
                New-RSReturnMessage -ReturnType Success -Message "User profile $UserName exists and is not loaded"
            }
        }
        elseif ($null -ne $checkExists -and $checkExclude) {
            New-RSReturnMessage -ReturnType Error -Message "User profile $UserName is excluded and will not be deleted"
        }
        else {
            New-RSReturnMessage -ReturnType Error -Message "User profile $UserName does not exist on the computer"
        }
    }
}
