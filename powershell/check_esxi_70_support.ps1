# Author: Florian Grehl - www.virten.net
# Reference: -
# Description: Check ESXi 7.0 support with JSON based HCL provided by www.virten.net 
#              (http://www.virten.net/2016/05/vmware-hcl-in-json-format/)
#
# Requires Check-HCL function (https://github.com/fgrehl/virten-scripts/blob/master/powershell/Check-HCL.ps1)


#$scope = Get-VMHost esx73.virten.lab 
#$scope = Get-Cluster Production | Get-VMHost
$scope = Get-VMHost

(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/fgrehl/virten-scripts/master/powershell/Check-HCL.ps1", "$Env:temp\Check-HCL.ps1")
. $Env:temp\Check-HCL.ps1
$check = Check-HCL $scope
foreach ($esx in $check){
  Write-Host "$($esx.VMHost) ($($esx.Model)): "  -NoNewline
  if($esx.SupportedReleases){
    if ($esx.SupportedReleases -match "7.0"){
      Write-Host "ESXi 7.0 supported" -ForegroundColor Green
    } else {
      Write-Host "ESXi 7.0 unsupported" -ForegroundColor Red
    }
  } else {
    Write-Host "unknown"
  }
}