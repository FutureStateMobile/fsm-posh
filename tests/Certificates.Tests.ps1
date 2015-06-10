$ErrorActionPreference = 'Stop'
$here = Split-Path $script:MyInvocation.MyCommand.Path


Describe 'Certificates' { 
    
    BeforeAll {
        $pth = $env:PATH
        if(! ($env:PATH.Contains('openssl'))){
            $pathToOpenSSL = Resolve-Path "$here\..\Tools\OpenSSL"
            $env:PATH += ";$pathToOpenSSL"
        }
    }
    
    AfterAll {
        $env:PATH = $pth
    }

    Context 'Create all 4 Certificates in a Chain using the combined method (New-PrivateKeyAndCertificateSigningRequest)' {
        # setup
        $name = 'test-cert'
        $password = (ConvertTo-SecureString 'password' -AsPlainText -Force)
        $subject = '/CN=test-foo'
        $out = New-Item 'TestDrive:\testDir2' -ItemType Directory -Force
        
        # execute
        $execute = {New-PrivateKeyAndCertificateSigningRequest $name $password $subject $out | New-Certificate | New-PfxCertificate -password $password}
        $result = .$execute
        
        # assert
        
        It 'Will have a .key file on the path' {
            (Test-Path "$out\$($name).key") | should be $true
        }
        
        It 'Will have a .crt file on the path' {
            (Test-Path "$out\$($name).crt") | should be $true
        }
        
        It 'Will have a .csr file on the path' {
            (Test-Path "$out\$($name).csr") | should be $true
        }
        
        It 'Will have a .pfx file on the path' {
            (Test-Path "$out\$($name).pfx") | should be $true
        }
        
        It 'Will not have a .cvg file on the path' {
            (Test-Path "$out\$($name).cvg") | should be $false
        }
        
    }
}