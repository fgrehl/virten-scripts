Function Check-HCL {
<#
  .NOTES
  Author: Florian Grehl - www.virten.net
  Reference: http://www.virten.net/2016/05/vmware-hcl-in-json-format/
  
  .DESCRIPTION
  Verifies server hardware against VMware HCL.
  This script uses a JSON based VMware HCL maintained by www.virten.net.
  Works well with HP and Dell. Works acceptable with IBM and Cisco.
  
  Many vendors do not use the same model string in VMware HCL and Server BIOS Information.
  Server may then falsely be reported as unsupported.

  .EXAMPLE
  Get-VMHost |Check-HCL 
  Check-HCL 
#>

  [CmdletBinding()]
  Param (
    [Parameter(ValueFromPipeline=$true)]
    $vmHosts
  )
  Begin{
    $esxiReleases = Invoke-WebRequest -Uri http://www.virten.net/repo/esxiReleases.json | ConvertFrom-Json
    $hclJson = Invoke-WebRequest -Uri http://www.virten.net/repo/vmware-hcl.json
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
    $jsonserializer= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
    $jsonserializer.MaxJsonLength = [int]::MaxValue
    $hcl = $jsonserializer.DeserializeObject($hclJson)
  }
  Process {
    if (-not $vmHosts) {
      $vmHosts = Get-VMHost
    }
    $AllInfo = @()
    Foreach ($vmHost in $vmHosts) {
      $HostManuf = $($vmHost.Manufacturer)
      $HostModel = $($vmHost.model)
      $HostCpu = $($vmHost.ProcessorType)
      $Info = "" | Select VMHost, Build, ReleaseLevel, Manufacturer, Model, Cpu, Supported, SupportedReleases, Reference, Note
      $Info.VMHost = $vmHost.Name
      $Info.Build = $vmHost.Build
      $Info.Manufacturer = $HostManuf
      $Info.Model = $HostModel
      $Info.Cpu = $HostCpu

      $release = $esxiReleases.data.esxiReleases |? build -eq $vmHost.Build
      if($release) {
        $updateRelease = $($release.updateRelease)
        $Info.ReleaseLevel = $updateRelease
      } else {
        $updateRelease = $false
        $Info.Note = "ESXi Build $($vmHost.Build) not found in database." 
      }


      $Data = @()
        Foreach ($server in $hcl.data.server) {
        $ModelFound = $false

        if ($HostModel.StartsWith("UCS") -and $ModelMatch.Contains("UCS")){
          $HostLen=$HostModel.Length
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
        $ModelMatch = $ModelMatch -replace "IBM ",""
        $ModelMatch = ("*"+$ModelMatch+"*")
        if ($HostManuf -eq "HP"){
          If ($HostModel -like $ModelMatch -and $server.manufacturer -eq $HostManuf) { 
            $ModelFound = $true
          }
        } else {
          If ($HostModel -like $ModelMatch) { 
            $ModelFound = $true
          }
        }

        If ($ModelFound) { 
          If($server.cpuSeries -like "Intel Xeon*"){
            $cpuSeriesMatch = $server.cpuSeries -replace "Intel Xeon ","" -replace " Series","" -replace "00","??" -replace "xx","??" -replace "-v"," v"
            $HostCpuMatch = $HostCpu -replace " 0 @"," @" -replace "- ","-" -replace "  "," "
            $cpuSeriesMatch = ("*"+$cpuSeriesMatch+" @*")
            if ($HostCpuMatch -notlike $cpuSeriesMatch){
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

      If ($Data.Count -eq 1){
        Foreach ($obj in $Data) {
          $release = $esxiReleases.data.esxiReleases |? build -eq $vmHost.Build
          if ($updateRelease -and ($obj.Releases -contains $updateRelease)){
            $Info.Supported = $true
          } else {
            $Info.Supported = $false
          }
          $Info.SupportedReleases = $obj.Releases
          $Info.Reference = $($obj.url)
        }
      } elseif ($Data.Count > 1){
        $Info.Note = "More than 2 HCL Entries found." 
      } else {
        $Info.supported = $false
        $Info.Note = "No HCL Entries found." 
      }
      $AllInfo += $Info
    }
    $AllInfo
  }
}