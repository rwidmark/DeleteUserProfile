Function Test-RSServiceModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$CallerName = "This function"
    )

    begin {
    }

    process {
        try {
            Get-InstalledModule -Name "rsServiceModule" -ErrorAction Stop | Out-Null
        }
        catch {
            throw "$CallerName requires rsServiceModule to be installed"
        }
    }

    end {
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
		YouTube:		https://www.youtube.com/@rwidmark
        Linkedin:       https://www.linkedin.com/in/rwidmark/
        GitHub:         https://github.com/rwidmark
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "Enter name of the computer or computers you want to collect user profiles from, multiple computer names are supported.")]
        [string[]]$ComputerName = "localhost"
    )

    begin {
        Test-RSServiceModule -CallerName $MyInvocation.MyCommand.Name
        $jobGetProfile = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($currentComputer in $ComputerName) {
            $job = Start-ThreadJob -Name $currentComputer -ThrottleLimit 50 -ArgumentList $currentComputer -ScriptBlock {
                param(
                    [string]$ComputerName
                )

                $cimSession = $null

                try {
                    Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
                    $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop

                    $getUserData = Get-CimInstance -CimSession $cimSession -ClassName Win32_UserProfile -ErrorAction Stop |
                        Where-Object { $_.Special -eq $false } |
                        Sort-Object -Descending -Property LastUseTime

                    if ($null -eq $getUserData) {
                        Write-Verbose "No user profiles found on $ComputerName"
                        return
                    }

                    foreach ($_profile in $getUserData) {
                        $notUsedFor = [ordered]@{}

                        if ($null -ne $_profile.LastUseTime) {
                            $timeSpan = New-TimeSpan -Start $_profile.LastUseTime -End (Get-Date)

                            if ($timeSpan.Days -gt 0) {
                                $notUsedFor.Add("days", "$($timeSpan.Days)")
                            }
                            if ($timeSpan.Hours -gt 0) {
                                $notUsedFor.Add("hours", "$($timeSpan.Hours)")
                            }
                            if ($timeSpan.Minutes -gt 0) {
                                $notUsedFor.Add("minutes", "$($timeSpan.Minutes)")
                            }

                            if ($notUsedFor.Count -eq 0) {
                                $notUsedFor.Add("minutes", "0")
                            }
                        }

                        [PSCustomObject]@{
                            Computer  = $ComputerName
                            UserName  = if ($null -ne $_profile.LocalPath) { Split-Path -Path $_profile.LocalPath -Leaf }
                            LocalPath = $_profile.LocalPath
                            LastUsed  = if ($null -ne $_profile.LastUseTime) { ($_profile.LastUseTime -as [DateTime]).ToString("yyyy-MM-dd HH:mm") }
                            Loaded    = $_profile.Loaded
                            NotUsed   = if ($notUsedFor.Count -gt 0) { $notUsedFor } else { "N/A" }
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

        .LINK
        https://github.com/rwidmark/DeleteUserProfile/blob/main/README.md

        .NOTES
        Author:         Robin Widmark
        Mail:           robin@widmark.dev
        Website/Blog:   https://widmark.dev
        X:              https://x.com/widmark_robin
        Mastodon:       https://mastodon.social/@rwidmark
		YouTube:		https://www.youtube.com/@rwidmark
        Linkedin:       https://www.linkedin.com/in/rwidmark/
        GitHub:         https://github.com/rwidmark
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "Enter computer name for the computer you want to delete user profiles from")]
        [string]$ComputerName = "localhost",
        [Parameter(Mandatory = $false, HelpMessage = "Enter the name of the user profiles that you want to delete, multiple names are supported")]
        [string[]]$UserName,
        [Parameter(Mandatory = $false, HelpMessage = "Use this switch if you want to delete all user profiles on the computer")]
        [switch]$All = $false,
        [Parameter(Mandatory = $false, HelpMessage = "Enter username of the user profiles that you want to exclude, multiple names are supported")]
        [string[]]$Exclude
    )

    begin {
        Test-RSServiceModule -CallerName $MyInvocation.MyCommand.Name
        $jobReturnMessage = [System.Collections.Generic.List[string]]::new()
        $jobDelete = [System.Collections.Generic.List[object]]::new()
    }

    process {
        $cimSession = $null

        try {
            Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
            $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop
            $getAllProfiles = Get-CimInstance -CimSession $cimSession -ClassName Win32_UserProfile -ErrorAction Stop | Where-Object { $_.Special -eq $false }
        }
        catch {
            Write-Error "${ComputerName}: $($PSItem.Exception.Message)"
            return
        }

        try {
            if ($All) {
                foreach ($_profile in $getAllProfiles) {
                    $userNameFromPath = if ($null -ne $_profile.LocalPath) { Split-Path -Path $_profile.LocalPath -Leaf }
                    $checkProfile = Confirm-RSProfile -UserName $userNameFromPath -ProfileData $getAllProfiles -Exclude $Exclude

                    if ($checkProfile.ReturnCode -eq 0) {
                        $job = Start-ThreadJob -Name $userNameFromPath -ThrottleLimit 50 -ArgumentList $_profile, $userNameFromPath -ScriptBlock {
                            param(
                                $Profile,
                                [string]$UserName
                            )

                            try {
                                Write-Verbose "Deleting user profile $UserName..."
                                $Profile | Remove-CimInstance -ErrorAction Stop
                                Write-Verbose "User profile $UserName is now deleted!"
                            }
                            catch {
                                Write-Error "${UserName}: $($PSItem.Exception.Message)"
                            }
                        }

                        [void]$jobDelete.Add($job)
                    }
                    else {
                        [void]$jobReturnMessage.Add("$($checkProfile.Message)")
                    }
                }
            }
            else {
                foreach ($_profile in $UserName) {
                    $checkProfile = Confirm-RSProfile -UserName $_profile -ProfileData $getAllProfiles -Exclude $Exclude

                    if ($checkProfile.ReturnCode -eq 0) {
                        $getProfile = $getAllProfiles | Where-Object { (Split-Path -Path $_.LocalPath -Leaf) -eq $_profile } | Select-Object -First 1

                        if ($null -eq $getProfile) {
                            [void]$jobReturnMessage.Add("User profile $($_profile) could not be resolved for deletion")
                            continue
                        }

                        $job = Start-ThreadJob -Name $_profile -ThrottleLimit 50 -ArgumentList $getProfile, $_profile -ScriptBlock {
                            param(
                                $Profile,
                                [string]$UserName
                            )

                            try {
                                Write-Verbose "Deleting user profile $UserName..."
                                $Profile | Remove-CimInstance -ErrorAction Stop
                                Write-Verbose "The user profile $UserName is now deleted!"
                            }
                            catch {
                                Write-Error "${UserName}: $($PSItem.Exception.Message)"
                            }
                        }

                        [void]$jobDelete.Add($job)
                    }
                    else {
                        [void]$jobReturnMessage.Add("$($checkProfile.Message)")
                    }
                }
            }
        }
        finally {
            if ($null -ne $cimSession) {
                $cimSession | Remove-CimSession -ErrorAction SilentlyContinue
            }
        }
    }

    end {
        if ($jobDelete.Count -gt 0) {
            try {
                Receive-Job -Job $jobDelete -AutoRemoveJob -Wait -ErrorAction Stop
            }
            catch {
                Write-Error $PSItem.Exception.Message
            }
        }

        if ($jobReturnMessage.Count -gt 0) {
            $jobReturnMessage
        }
    }
}

Function Confirm-RSProfile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Username of the user you want to verify")]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,
        [Parameter(Mandatory = $true, HelpMessage = ".")]
        [ValidateNotNullOrEmpty()]
        $ProfileData,
        [Parameter(Mandatory = $false, HelpMessage = "Enter the username you want to exclude from deletion")]
        [String[]]$Exclude
    )

    begin {
    }

    process {
        $checkExists = $ProfileData | Where-Object { (Split-Path -Path $_.LocalPath -Leaf) -eq $UserName } | Select-Object -First 1
        $checkExclude = @($Exclude) -contains $UserName

        if ($null -ne $checkExists -and -not $checkExclude) {
            if ($checkExists.Loaded -eq $true) {
                Get-ReturnMessageTemplate -ReturnType Error -Message "User profile $($UserName) is loaded and cannot be removed"
            }
            else {
                Get-ReturnMessageTemplate -ReturnType Success -Message "User profile $($UserName) exists and is not loaded"
            }
        }
        elseif ($null -ne $checkExists -and $checkExclude) {
            Get-ReturnMessageTemplate -ReturnType Error -Message "User profile $($UserName) is excluded and will not be deleted"
        }
        else {
            Get-ReturnMessageTemplate -ReturnType Error -Message "User profile $($UserName) does not exist on the computer"
        }
    }

    end {
    }
}
