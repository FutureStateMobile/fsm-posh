<#
    .DESCRIPTION
        Will register a mimetype for a file extension.

    .EXAMPLE
        Add-IISMimeType "cls-w-85544.transcanada.com" "json" "application/json"

    .PARAMETER siteName
        The name of the IIS site.

    .PARAMETER fileExtension
        The file extension to map to the mime type.

    .PARAMETER mimeType
        The mime type name.

    .SYNOPSIS
        Will add a mapping for the file extension to the mime type on the named IIS site.
#>

function Add-IISMimeType
{
    param(
        [parameter( Mandatory=$true, position=0 )] [string] $siteName,
        [parameter( Mandatory=$true, position=1 )] [string] $fileExtension,
        [parameter( Mandatory=$true, position=2 )] [string] $mimeType
    )

    $ErrorActionPreference = "Stop"

    Write-Output "Adding mime type $mimeType for extension $fileExtension to IIS site $siteName."

    $appcmd = "$env:windir\system32\inetsrv\appcmd.exe"

    & $appcmd set config $siteName /section:staticContent /+"[fileExtension='.$fileExtension',mimeType='$mimeType']"

    Write-Output "Added mime type $mimeType for extension $fileExtension to IIS site $siteName."
}