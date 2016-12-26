# Author: Florian Grehl - www.virten.net
# Reference: http://www.virten.net/2016/04/esxi-version-information-now-available-as-json-incl-script-example/ 
# Description: ESXi Build Numbers JSON demonstration
#

$esxiReleases = Invoke-WebRequest -Uri http://www.virten.net/repo/esxiReleases.json | ConvertFrom-Json
$vmHosts = Get-VMHost
$AllInfo = @()

Foreach ($vmHost in $vmHosts) {
  $buildFound = $false
  $Info = "" | Select VMHost, Build, ReleaseLevel, PatchLevel, ReleaseDate, UpdateAvailable, LatestPatch, LatestBuild
  Write-Host "ESXi Host $($vmHost.Name) is running on Build $($vmHost.Build)"
  $Info.VMHost = $vmHost.Name
  $Info.Build = $vmHost.Build

  Foreach ($release in $esxiReleases.data.esxiReleases) {
    If ($vmHost.Build -eq $release.Build) {
      Write-Host " - Release Level: $($release.releaseLevel)"
      $Info.ReleaseLevel = $release.releaseLevel
      Write-Host " - Patch Level: $($release.friendlyName)"
      $Info.PatchLevel = $release.friendlyName
      Write-Host " - Release Date: $($release.releaseDate)"
      $Info.ReleaseDate = $release.releaseDate
      $minorRelease = $($release.minorRelease)
      $buildFound = $true
             
      Foreach ($rel in $esxiReleases.data.esxiReleases) {
        If ($minorRelease -eq $rel.minorRelease) {
          $latestBuild = $rel.build
          $latestPatch = $rel.friendlyName
          break
        }
      }
    
      if($latestBuild -eq $vmHost.Build) {
        Write-Host " - $($vmHost.Name) is running the latest version!"  -ForegroundColor Green
        $Info.UpdateAvailable = $false
      } else {
        Write-Host " - $($vmHost.Name) update available: $($latestPatch) ($($latestBuild))"  -ForegroundColor Red
        $Info.UpdateAvailable = $true
        $Info.LatestPatch = $latestPatch
        $Info.LatestBuild = $latestBuild
      }
    }
  }
  If (-Not $buildFound){
    Write-Host " - Build $($vmHost.Build) not found in database!" -ForegroundColor Red
  }
  $AllInfo += $Info
}


# $AllInfo | Export-Csv -NoTypeInformation esxi.csv
