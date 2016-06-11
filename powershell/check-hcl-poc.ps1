# Check ESXi Hosts against VMware HCL
# Does not use live VMware HCL data, but a copied JSON based version
# Needs to be connected to a vCenter Server (Connect-VIServer), or can use fake data from a CSV
# Does not upload any sensitive information. Downloads a full HCL copy and compares it locally.
# Script is just a Proof of Concept...
#
# Todo:
# - Match Model when the BIOS string differs from HCL
# - Identify CPU Series based on specific CPU

# Load ESXiReleases JSON from www.virten.net to match Builds corresponding Update (eg. Esxi 5.5 U1)
$esxiReleases = Invoke-WebRequest -Uri http://www.virten.net/repo/esxiReleases.json | ConvertFrom-Json
# Offline Version (Download the Json and put it locally to test
#$esxiReleases = Get-Content repo/esxiReleases.json | ConvertFrom-Json


# Load JSON bases HCL
Write-Host "Loading HCL Data.."
# HCL to large for "ConvertFrom-Json". JavaScriptSerializer must do it...
$hclJson = Invoke-WebRequest -Uri http://www.virten.net/repo/vmware-hcl.json
#$hclJson = Get-Content repo/vmware-hcl.json # Offline Version
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
$jsonserializer= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
$jsonserializer.MaxJsonLength = [int]::MaxValue
$hcl = $jsonserializer.DeserializeObject($hclJson)

Write-Host "Loading ESXi Hosts..."
# Can also use a "Fake List" from a CSV File
# Export List with: Get-VMHost |select Name,Build,Manufacturer,Model,ProcessorType |Export-Csv fakehosts.csv -NoTypeInformation
$vmHosts = Get-VMHost
#$vmHosts = Import-Csv 'fakehosts.csv' -Delimiter ';'


Foreach ($vmHost in $vmHosts) {
  Write-Host "`r`nESXi Host: " -NoNewline
  Write-Host $vmHost.Name -ForegroundColor Cyan
  Write-Host " - ESXi Build Number: " -NoNewline
  Write-Host $vmHost.Build -ForegroundColor Cyan

  # Search local Build in JSON builds from virten.net to find the correct release like ESXi 6.0u2 or ESXi 5.5u1.
  # This information is required to match against the HCL.
  $release = $esxiReleases.data.esxiReleases |? build -eq $vmHost.Build
  if($release) {
    $updateRelease = $($release.updateRelease)
    $HostManuf = $($vmHost.Manufacturer)
    $HostModel = $($vmHost.model)
    $HostCpu = $($vmHost.ProcessorType)
    Write-Host " - Release Level (To match HCL): " -NoNewline
    Write-Host $updateRelease -ForegroundColor Cyan
    Write-Host " - Hardware Vendor: " -NoNewline
    Write-Host $HostManuf -ForegroundColor Cyan
    Write-Host " - Hardware Model: " -NoNewline
    Write-Host $HostModel -ForegroundColor Cyan
    Write-Host " - CPU Model: " -NoNewline
    Write-Host $HostCpu -ForegroundColor Cyan
  } else {
    # If the build is unknown, and it's not a beta, please contact me flo@virten.net 
    # ...or wait a couple of days when the release is brand new.
    Write-Host " - Build $($vmHost.Build) not found in database!" -ForegroundColor Red
    continue
  }


  # Compare Server Model against my JSON HCL. Models can be found in the HCL multiple times
  # because Model+CPU is required to match the hardware.
  $Data = @()
  Foreach ($server in $hcl.data.server) {
    # -eq works great with HP and Dell. No Problems at all
    # IBM includs Part Numbers. Nice, but bad for comparison. Some fuzzy compare might be required...
    # Cisco UCS models do not match either. Also some fuzziness required
    # ...need more Hardware to test. 
    #If ($HostModel -eq $server.model) { # Works vor HP and Dell, where string matches 100%
    $ModelFound = $false
    if ($HostModel.StartsWith("UCS") -and $ModelMatch.Contains("UCS")){
      $HostLen=$HostModel.Length

      #   UCSB - B200 -  M  3
      #   1234 5 6789 10 11 12

      #   UCSC - C240 -  M  3  S  2
      #   1234 5 6579 10 11 12 13 14      
      $UCS_MODEL=$HostModel.Substring(5,4)
      if ($HostLen -eq 12) {
        $UCS_GEN=$HostModel.Substring(10,2)
      }
      if ($HostLen -eq 14) {
        $UCS_GEN=$HostModel.Substring(10,3)
      }

      $isUCSMODEL=$ModelMatch.Contains($UCS_MODEL)
      if ($isUCSMODEL -eq "True") {
        $isUCSGEN=$ModelMatch.Contains($UCS_GEN)
        if ($isUCSGEN -eq "True") {
          $ModelFound = $true
        }
      }
    }

    $ModelMatch = $server.model 
    $ModelMatch = $ModelMatch -replace "IBM ","" # IBM writes "IBM" in front of models sometimes. Need to remove it
    $ModelMatch = ("*"+$ModelMatch+"*") # Not all entries are 100% matches. Simple wildcard matching
    #Write-Host "Model Match String:" $ModelMatch
    If ($HostModel -like $ModelMatch) { 
      $ModelFound = $true
    }

    If ($ModelFound) { 
      # Matching CPU Series to CPU Model requires fuzzy matching
      # This filter works with Intel Xenon CPUs:
      if($server.cpuSeries -like "Intel Xeon*"){
        $cpuSeriesMatch = $server.cpuSeries -replace "Intel Xeon ","" -replace " Series","" -replace "00","??" -replace "xx","??"  -replace "-v"," v"
        $cpuSeriesMatch = ("*"+$cpuSeriesMatch+" @*")
        #Write-Host "CPU Series Match String:" $cpuSeriesMatch
        if ($HostCpu -notlike $cpuSeriesMatch){
          continue
        }
      }
      

      $helper = New-Object PSObject
      Add-Member -InputObject $helper -MemberType NoteProperty -Name Model $server.model
      Add-Member -InputObject $helper -MemberType NoteProperty -Name CPU $server.cpuSeries
      Add-Member -InputObject $helper -MemberType NoteProperty -Name Releases $server.releases
      Add-Member -InputObject $helper -MemberType NoteProperty -Name URL $server.url
      $Data += $helper
    }
  }
  Write-Host " -- Found $($Data.Count) HCL Entries..."

  # Display matches...
  if ($Data.Count){
    Foreach ($obj in $Data) {
      Write-Host " -- " -NoNewline
      Write-Host "$($obj.Model)" -ForegroundColor Yellow -NoNewline
      Write-Host " with CPU " -NoNewline
      Write-Host $($obj.CPU) -NoNewline -ForegroundColor Yellow
      $relFound = $false
      $release = $esxiReleases.data.esxiReleases |? build -eq $vmHost.Build
      
      if ($obj.Releases -contains $updateRelease){
        Write-Host " is supported in " -NoNewline
        Write-Host "$($updateRelease) " -ForegroundColor Green
      } else {
        Write-Host " is not supported in " -NoNewline
        Write-Host "$($updateRelease) " -ForegroundColor Red
      }
             
      # Optional: Display releases that are supported for this Hardware+CPU Combo.
      # Maybe useful to check if it's ok to upgrade the server
      # Displays only 5.x and 6.x Releases
      Write-Host " --- Supported: " -NoNewline
      $supportedReleases = ""
      $supportedReleases = $obj.Releases|? {$_ -notmatch "Installable|Embedded|ESX "}
      if($supportedReleases){
        $supportedReleases.Replace("ESXi ","") -join ", "
      } else {
        Write-Host "Only systems < vSphere 5 are supported, but they are filtered by the script."
      }

      # Optional: Display Original HCL Link for verification 
      Write-Host " --- HCL Link: $($obj.url)"
    }
  }
}