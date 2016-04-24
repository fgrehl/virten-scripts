$vmwareProductLifecycle = Invoke-WebRequest -Uri http://www.virten.net/repo/vmwareProductLifecycle.json | ConvertFrom-Json
$vmHosts = Get-VMHost

Foreach ($vmHost in $vmHosts) {
  $releaseFound = $false
  $product = "VMware ESXi $($vmHost.ApiVersion)"

  Write-Host "$($vmHost.Name) is running Version $($product)"
  
  Foreach ($prod in $vmwareProductLifecycle.data.productLifecycle) {
    If ($product -eq $prod.productRelease) {
      $TimeSpanEogs = New-TimeSpan –Start (get-date) –End (get-date $prod.endOfGeneralSupport)
      $TimeSpanEotg = New-TimeSpan –Start (get-date) –End (get-date $prod.endOfTechnicalGuidance)
      Write-Host " - End of Genereal Support: $($prod.endOfGeneralSupport) ($($TimeSpanEogs.days) Days)"
      Write-Host " - End of Technical Guidance: $($prod.endOfTechnicalGuidance) ($($TimeSpanEotg.days) Days)"
      $releaseFound = $true
    }
  }
  
  If (-Not $releaseFound){
    Write-Host " - $($product) not found in database!" -ForegroundColor Red
  }
}