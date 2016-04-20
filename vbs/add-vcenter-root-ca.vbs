Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objApp = CreateObject("Shell.Application")
Set objShell = CreateObject("WScript.Shell")

dim vCenterName
vCenterName = inputbox("Add vSphere 6.0 PSC trusted root CA certificates to the local certificate store. Please enter vCenter Server Address (eg. vcenter.example.com)", "Enter vCenter Server URL", "")
if vCenterName = "" then
  wscript.quit
end if

CaCert = "./" & vCenterName & "-cacert.zip"
CaDir  = "./" & vCenterName & "-cacert/"
Set newDIR = objFSO.CreateFolder( CaDir )

const SXH_SERVER_CERT_IGNORE_ALL_SERVER_ERRORS = 13056
dim xHttp: Set xHttp = createobject("MSXML2.ServerXMLHTTP")
dim bStrm: Set bStrm = createobject("Adodb.Stream")
xHttp.Open "GET", "https://" & vCenterName & "/certs/download", False
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

CertFolder = CaDir & "certs/"
Set objFolder = objFSO.GetFolder(CertFolder)
Set colFiles = objFolder.Files
For Each objFile in colFiles
  objShell.run "certutil.exe -addstore Root "& CertFolder & objFile.Name 
Next

