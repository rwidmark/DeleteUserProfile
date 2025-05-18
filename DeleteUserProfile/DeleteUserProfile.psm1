Function Get-RSUserProfile {
    <#
        .SYNOPSIS
        Return all user profiles that are saved on a computer

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
        https://github.com/rstolpe/DeleteUserProfile/blob/main/README.md

        .NOTES
        Author:         Robin Widmark
        Mail:           robin@widmark.dev
        Blog:           https://widmark.dev
        Twitter:        https://twitter.com/rstolpes
        Linkedin:       https://www.linkedin.com/in/rstolpe/
        GitHub:         https://github.com/rstolpe
        PSGallery:      https://www.powershellgallery.com/profiles/rstolpe
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "Enter name of the computer or computers you want to collect user profiles from, multiple computer names are supported.")]
        [string[]]$ComputerName = "localhost"
    )

    $CheckServiceModule = $(try { Get-InstalledModule -Name "rsServiceModule" -ErrorAction SilentlyContinue } catch { $null })
    If ($null -eq $CheckServiceModule) {
        Write-Error "You must have rsServiceModule installed to use this function"
        break
    }
    
    $JobGetProfile = foreach ($_computer in $ComputerName) {
        Start-ThreadJob -Name $_computer -ThrottleLimit 50 -ScriptBlock {
            $CheckComputer = $(try { Test-WSMan -ComputerName $Using:_computer -ErrorAction SilentlyContinue } catch { $null })

            if ($null -ne $CheckComputer) {
                try {
                    # Open CIM Session
                    $CimSession = $(try { New-CimSession -ComputerName $Using:_computer -ErrorAction SilentlyContinue } catch { $null })

                    if ($null -ne $CimSession) {
                        # Collect all user profiles
                        $GetUserData = Get-CimInstance -CimSession $CimSession -className Win32_UserProfile | Where-Object { $_.Special -eq $false } | Select-Object LocalPath, LastUseTime, Loaded | Sort-Object -Descending -Property LastUseTime
                    
                        $UserProfileData = foreach ($_profile in $GetUserData) {
                            $NotUsedFor = [ordered]@{}
                            # Calculate how long it was the profile was used
                            if (-Not([string]::IsNullOrEmpty($_profile.LastUseTime))) {
                                NEW-TIMESPAN -Start $_profile.LastUseTime -End (Get-Date) | Select-Object days, hours, Minutes  | Foreach-Object {
                                    if ($Null -ne $_.Days -or $_.Days -gt "0") {
                                        $NotUsedFor.Add("days", "$($_.Days)")
                                    }
                                    if ($Null -ne $_.Hours -or $_.Hours -gt "0") {
                                        $NotUsedFor.Add("hours", "$($_.Hours)")
                                    }
                                    if ($Null -ne $_.Minutes -or $_.Minutes -gt "0") {
                                        $NotUsedFor.Add("minutes", "$($_.Minutes)")
                                    }
                                }
                            }

                            [PSCustomObject]@{
                                Computer  = $Using:_computer
                                UserName  = if ($null -ne $_profile.LocalPath) { $_profile.LocalPath.split('\')[-1] }
                                LocalPath = if ($null -ne $_profile.LocalPath) { $_profile.LocalPath }
                                LastUsed  = if ($null -ne $_profile.LastUseTime) { ($_profile.LastUseTime -as [DateTime]).ToString("yyyy-MM-dd HH:mm") }
                                Loaded    = if ($null -ne $_profile.Loaded) { $_profile.Loaded }
                                NotUsed   = if (-Not([string]::IsNullOrEmpty($NotUsedFor))) { $NotUsedFor } else { "N/A" }
                            }
                        }

                        if ($null -ne $UserProfileData) {
                            return $UserProfileData
                        }
                        else {
                            Write-Output "No user profiles found on $($Using:_computer)"
                            continue
                        }
                    }
                    else {
                        Write-Error "Could not connect to $($Using:_computer) trough WinRM, please check the connection and try again"
                        continue
                    }
                }
                catch {
                    Write-Output "$($PSItem.Exception.Message)"
                    continue
                }
            }
            else {
                Write-Error "Could not establish connection against $($Using:_computer)"
                continue
            }
        }
    }

    $ReturnProfiles = Receive-Job $JobGetProfile -AutoRemoveJob -Wait
    return $ReturnProfiles
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
        https://github.com/rstolpe/DeleteUserProfile/blob/main/README.md

        .NOTES
        Author:         Robin Widmark
        Mail:           robin@widmark.dev
        Blog:           https://widmark.dev
        Twitter:        https://twitter.com/rstolpes
        Linkedin:       https://www.linkedin.com/in/rstolpe/
        GitHub:         https://github.com/rstolpe
        PSGallery:      https://www.powershellgallery.com/profiles/rstolpe
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

    $CheckServiceModule = $(try { Get-InstalledModule -Name "rsServiceModule" -ErrorAction SilentlyContinue } catch { $null })
    If ($null -eq $CheckServiceModule) {
        Write-Error "You must have rsServiceModule installed to use this function"
        break
    }

    <#if ($null -eq $UserName -and $All -eq $false) {
        Write-Error "You must enter a username or use the switch -All to delete user profiles!"
        break
    }#>

    $JobReturnMessage = [System.Collections.ArrayList]::new()
    $CheckComputer = $(try { Test-WSMan -ComputerName $ComputerName -ErrorAction SilentlyContinue } catch { $null })

    if ($null -ne $CheckComputer) {
        # Open CIM Session
        $CimSession = $(try { New-CimSession -ComputerName $ComputerName -ErrorAction SilentlyContinue } catch { $null })
        # Collecting all user profiles on the computer
        if ($null -ne $CimSession) {
            $GetAllProfiles = Get-CimInstance -CimSession $CimSession -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }

            # Deleting all user profiles on the computer besides them that are special or loaded
            if ($All -eq $true) {
                $JobDelete = foreach ($_profile in $GetAllProfiles) {
                    $UserNameFromPath = $_profile.LocalPath.split('\')[-1]
                    $CheckProfile = Confirm-RSProfile -UserName $UserNameFromPath -ProfileData $GetAllProfiles -Exclude $Exclude

                    if ($CheckProfile.ReturnCode -eq 0) {
                        # Starting thread job to speed things up
                        Start-ThreadJob -Name $UserNameFromPath -ThrottleLimit 50 -ScriptBlock {
                            try {
                                Write-Output "Deleting user profile $($Using:UserNameFromPath)..."
                                $Using:_profile | Remove-CimInstance
                                Write-Output "User profile $($Using:UserNameFromPath) are now deleted!"
                            }
                            catch {
                                Write-Error "$($PSItem.Exception)"
                                continue
                            }
                        }
                    }
                    else {
                        [void]($JobReturnMessage.Add("$($CheckProfile.Message)"))
                        continue
                    }
                }
            }
            # if you don't want to delete all profiles but just one or more
            elseif ($All -eq $false) {
                $JobDelete = foreach ($_profile in $UserName) {
                    $CheckProfile = Confirm-RSProfile -UserName $_profile -ProfileData $GetAllProfiles -Exclude $Exclude

                    if ($CheckProfile.ReturnCode -eq 0) {
                        $GetProfile = $GetAllProfiles | Where-Object { $_.LocalPath -like "*$($_profile)" }
                        Start-ThreadJob -Name $_profile -ThrottleLimit 50 -ScriptBlock {
                            Write-Output "Deleting user profile $($Using:_profile)..."
                            try {
                                $Using:GetProfile | Remove-CimInstance -ErrorAction SilentlyContinue
                                Write-Output "The user profile $($Using:_profile) are now deleted!"
                            }
                            catch {
                                Write-Error "$($PSItem.Exception)"
                                continue
                            }
                        }
                    }
                    else {
                        [void]($JobReturnMessage.Add("$($CheckProfile.Message)"))
                        continue
                    }
                }
            }

            if ($null -ne $JobDelete) {
                $ReturnProfileJob = Receive-Job $JobDelete -AutoRemoveJob -Wait
                $ReturnProfileJob
                $JobReturnMessage
            }
            else {
                $ReturnProfileJob
                $JobReturnMessage
            }
        }
        else {
            Write-Error "Could not connect to $($_computer) trough WinRM, please check the connection and try again"
            continue
        }
    }
    else {
        Write-Error "Could not establish connection against $($_computer)"
        continue
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
        [ValidateNotNullOrEmpty()]
        [String[]]$Exclude
    )

    $CheckExists = $ProfileData | Where-Object { $_.LocalPath -like "*$($UserName)" }
    if ($UserName -in $Exclude) {
        $CheckExclude = $true
    }
    else {
        $CheckExclude = $false
    }

    if ($null -ne $CheckExists -and $CheckExclude -eq $false) {
        if ($CheckExists.Loaded -eq $true) {
            Get-ReturnMessageTemplate -ReturnType Error -Message "User profile $($UserName) are loaded can't remove it"
        }
        else {
            Get-ReturnMessageTemplate -ReturnType Success -Message "User profile $($UserName) exists and are not loaded"
        }
    }
    elseif ($null -ne $CheckExists -and $CheckExclude -eq $true) {
        Get-ReturnMessageTemplate -ReturnType Error -Message "User profile $($UserName) are excluded and will not be deleted"
    }
    else {
        Get-ReturnMessageTemplate -ReturnType Error -Message "User profile $($UserName) does not exist on the computer"
    }
}