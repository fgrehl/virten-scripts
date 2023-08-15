# PowerShell script to get CPUID information from ESXi Hosts to identify CPU in Intels Security Issues table
# Reference: https://www.intel.com/content/www/us/en/developer/topic-technology/software-security-guidance/processors-affected-consolidated-product-cpu-model.html

Get-VMHost | ForEach-Object {
    $esx = $_
    $(Get-EsxCli -VMhost $esx -V2).hardware.cpu.list.Invoke() | Select-Object -First 1 | Select-Object `
    @{N = "Name"; E = { $esx.Name } },
    @{N = "CPU"; E = { $esx.ProcessorType } },
    @{N = "Family"; E = { '{0:X}' -f ([int]$_.Family) } },
    @{N = "Model"; E = { '{0:X}' -f ([int]$_.Model) } },
    @{N = "CPUID"; E = { "$(('{0:X}' -f ([int]$_.Family)).PadLeft(2, '0'))_$(('{0:X}' -f ([int]$_.Model)).PadLeft(2, '0'))H" } },
    @{N = "stepping"; E = { '{0:X}' -f ([int]$_.Stepping) } }
} | Format-Table -AutoSize
