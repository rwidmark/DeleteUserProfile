![GitHub](https://img.shields.io/github/license/rwidmark/DeleteUserProfile?style=plastic)  
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/rwidmark/DeleteUserProfile?sort=semver&style=plastic)  ![Last release](https://img.shields.io/github/release-date/rwidmark/DeleteUserProfile?style=plastic)
![GitHub last commit](https://img.shields.io/github/last-commit/rwidmark/DeleteUserProfile?style=plastic)  
![PSGallery downloads](https://img.shields.io/powershellgallery/dt/DeleteUserProfile?style=plastic)  
  
![Twitter](https://img.shields.io/twitter/follow/widmark_robin)

# DeleteUserProfile
This module will let you show all of the user profiles that are saved on a local or remote computer, you can also delete one specific user profile or all of the profiles.  
You can also return the user profiles from multiple computers at the same time.  
The special windows profiles are excluded.  
  
I have also made a blog post of it at my [blog](https://widmark.dev/remove-user-profiles-from-windows/)

## This module will do the following
- Return all of the user profiles from a remote or local computer
- Delete one specific user profile or all of the user profiles from a local or remote computer
- Delete all user profiles from both local and remote computer
- You can exclude user profiles to show
- You can exclude user profile to be deleted
- If the user profile are loaded it will not get deleted
- The special windows profiles are excluded

# Links
* [My PowerShell Collection](https://github.com/rwidmark/PSCollection)
* [Webpage/Blog](https://widmark.dev)
* [X](https://twitter.com/widmark_robin)
* [Mastodon](https://mastodon.social/@rwidmark)
* [YouTube](https://www.youtube.com/@rwidmark)
* [LinkedIn](https://www.linkedin.com/in/rwidmark/)
* [GitHub](https://github.com/rwidmark)

## Dependencies
- WinRM must be activated on the computer (Guide for it coming soon)
- Module also require that you have my service module installed, [rsServiceModule](https://github.com/rwidmark/rsServiceModule)

## Install
Install for current user
```
Install-Module -Name DeleteUserProfile -Scope CurrentUser -Force
```
  
Install for all users
```
Install-Module -Name DeleteUserProfile -Scope AllUsers -Force
```

## Example
### Get-RSUserProfile
If you want to use this on a remote computer just add the parameter ```-ComputerName {COMPUTERNAME}``` in the commands below.  
  
```
Get-RSUserProfile
```
Return all user profiles that are saved on the local computer

```
Get-RSUserProfile -Exclude "Frank", "rwidmark"
```
This will return all of the user profiles saved on the local machine except user profiles that are named Frank and rwidmark

```
Get-RSUserProfile -ComputerName "Win11-Test", "Win10"
```
This will return all of the user profiles saved on the remote computers named Win11-Test and Win10

### Remove-RSUserProfile
If you want to use this on a remote computer just add the parameter ```-ComputerName <COMPUTERNAME>``` in the commands below.  
  
```
Remove-RSUserProfile -All
```
This will delete all of the user profiles from the localhost / computer your running the module from.

```
Remove-RSUserProfile -Exclude "User1", "User2" -All
```
This will delete all of the user profiles except user profile User1 and User2 on the local computer

```
Remove-RSUserProfile -UserName "User1", "User2"
```
This will delete only user profile "User1" and "User2" from the local computer where you run the script from.