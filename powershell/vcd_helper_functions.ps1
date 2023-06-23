# Get-SessionId is a helper function that gets the SessionId of the vCloud
# session (Connect-CIServer) that matches the specified vCD Host endpoint.
# Returns SessionId as a [string] or empty string if matching session is
# not found.
Function Get-SessionId(
    [string]$Server
) {
    if ($Global:DefaultCIServers.Count -eq 1) {
        if ($Server) {
            if ($Global:DefaultCIServers.Name -eq $Server) {
                return $Global:DefaultCIServers.SessionID
            }
            else {
                Write-Error("The specified Server is not currently connected, connect first using Connect-CIServer.")
            }
        }
        else {
            return $Global:DefaultCIServers.SessionID
        }
    }
    else {
        if (!$Server) {
            Write-Error("No Server specified and connected to multiple servers, please use the -Server option to specify which connection should be used for this operation.")
            return
        }
        $mySessionID = ($Global:DefaultCIServers | Where-Object { $_.Name -eq $Server }).SessionID
        if (!$mySessionID) { 
            Write-Error("Cannot find a connection that matches Server $Server, connect first using Connect-CIServer.")
            return
        }         
        return $mySessionID   
    }
}


# Get-APIVersion is a helper function that retrieves the highest supported
# API version from the given vCD endpoint. This ensures that commands are not
# run against unsupported versions of the vCloud Director API.
Function Get-APIVersion(
    [string]$Server
) {
    $Server = Get-Server -Server $Server

    if ($Server) {
        try {
            [xml]$apiversions = Invoke-WebRequest -Uri "https://$Server/api/versions" -Method Get -Headers @{"Accept" = 'application/*+xml' }
        }
        catch {
            Write-Error ("Could not retrieve API versions, Status Code is $($_.Exception.Response.StatusCode.Value__).")
            Write-Error ("This can be caused by an untrusted SSL certificate on your Server.")
            return   
        }
        return [int](($apiversions.SupportedVersions.VersionInfo | Where-Object { $_.deprecated -eq $false } | Sort-Object Version -Descending | Select-Object -First 1).Version)
    }
    else {
        Write-Error ("Could not establish Server, if you are connected to multiple servers you must specify -Server option.")
    }
}


# Get-Server is a helper function to identify the correct Server value to
# be used (specified directly, default if only 1 connection to vCD or empty
# otherwise).
Function Get-Server(
    [string]$Server
) {
    if ($Server) { return $Server }
    if ($global:DefaultCIServers.Count -gt 1) { return }
    return $global:DefaultCIServers.ServiceUri.Host
}


# Get-AuthHeader is a helper function to create the authentication header based
# on the receieved Session Secret (Since PowerCLI 13.1 a Bearer Token is used)
Function Get-AuthHeader(
    [string]$Server
) {
    $Server = Get-Server -Server $Server
    $CISessionId = Get-SessionId($Server)
    if ($CISessionId.StartsWith("Bearer ")) { 
        Write-Debug "Connected to $($Server) using Bearer Token (PowerCLI 13.1 and later)"
        return @{ "Authorization" = $CISessionId } 
    }
    else { 
        Write-Debug "Connected to $($Server) using legacy SID"
        return @{ "x-vcloud-authorization" = $CISessionId } 
    }
}
