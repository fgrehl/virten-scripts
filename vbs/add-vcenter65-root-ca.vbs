' Script to add vSphere 6.5 CA to root Store
' Works with Windows 7, Windows 8 & Windows 10
' Florian Grehl - www.virten.net

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objApp = CreateObject("Shell.Application")
Set objShell = CreateObject("WScript.Shell")

If Not WScript.Arguments.Named.Exists("elevate") Then
  CreateObject("Shell.Application").ShellExecute WScript.FullName _
    , """" & WScript.ScriptFullName & """ /elevate", "", "runas", 1
  WScript.Quit
End If

dim vCenterName
vCenterName = inputbox("Add vSphere 6.5 PSC trusted root CA certificates to the local certificate store. Please enter vCenter Server Address (eg. vcenter.example.com)", "Enter vCenter Server URL", "")
if vCenterName = "" then
  wscript.quit
end if

CaCert = "./" & vCenterName & "-cacert.zip"
CaDir  = "./" & vCenterName & "-cacert/"
Set newDIR = objFSO.CreateFolder( CaDir )

const SXH_SERVER_CERT_IGNORE_ALL_SERVER_ERRORS = 13056
dim xHttp: Set xHttp = createobject("MSXML2.ServerXMLHTTP")
dim bStrm: Set bStrm = createobject("Adodb.Stream")
xHttp.Open "GET", "https://" & vCenterName & "/certs/download.zip", False
xHttp.setOption 2, SXH_SERVER_CERT_IGNORE_ALL_SERVER_ERRORS
xHttp.Send
with bStrm
  .type = 1
  .open
  .write xHttp.responseBody
  .savetofile CaCert, 2
end with
 
Set unzip=objApp.NameSpace(objFSO.GetAbsolutePathName(CaCert)).Items()
objApp.NameSpace(objFSO.GetAbsolutePathName(CaDir)).copyHere unzip, 16

CertFolder = CaDir & "certs/win/"
Set objFolder = objFSO.GetFolder(CertFolder)
Set colFiles = objFolder.Files
For Each objFile in colFiles
  objShell.run "certutil.exe -addstore Root "& CertFolder & objFile.Name 
Next

