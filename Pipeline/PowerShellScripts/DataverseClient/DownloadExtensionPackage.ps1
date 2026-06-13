<#
.SYNOPSIS
    Downloads a CSU extension package from Dataverse.

.DESCRIPTION
    Connects to the specified Dataverse environment, queries for a CSU extension
    package record by name and version, and downloads the package file to the
    specified output directory.

.PARAMETER PackageName
    The name of the CSU extension package to download.

.PARAMETER PackageVersion
    The version of the CSU extension package to download.

.PARAMETER OutputDirectory
    The directory to save the downloaded package file to.

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com/).

.PARAMETER TenantId
    Azure AD tenant ID.

.PARAMETER ClientId
    Azure AD application (client) ID.

.PARAMETER ClientSecret
    Azure AD application client secret. Required if CertificateThumbprint is not provided.

.PARAMETER CertificateThumbprint
    Thumbprint of a certificate for authentication. Preferred over ClientSecret when both are provided.

.PARAMETER Interactive
    If specified, signs the user in interactively in a browser (OAuth 2.0 Authorization
    Code + PKCE) instead of using a client secret or certificate. Intended for local /
    developer use only. When set, ClientSecret and CertificateThumbprint are ignored, and
    ClientId is optional (defaults to a Microsoft well-known public client with Dataverse
    pre-consent).
#>
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $PackageName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $PackageVersion,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [String]
    $OutputDirectory,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $EnvironmentUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $TenantId,

    [Parameter()]
    [String]
    $ClientId,

    [Parameter()]
    [String]
    $ClientSecret,

    [Parameter()]
    [String]
    $CertificateThumbprint,

    [Parameter()]
    [Switch]
    $Interactive
)

if (-not $Interactive -and [string]::IsNullOrWhiteSpace($ClientId)) {
    throw "ClientId is required when -Interactive is not specified."
}
if (-not $Interactive -and -not $CertificateThumbprint -and -not $ClientSecret) {
    throw "Either -CertificateThumbprint or -ClientSecret is required when -Interactive is not specified."
}

$ErrorActionPreference = 'Stop'

Write-Host "Starting CSU extension package download...`n"

# ── Load Dataverse client modules ────────────────────────────────────────────
. $PSScriptRoot\Common\Core.ps1
. $PSScriptRoot\Common\CommonFunctions.ps1
. $PSScriptRoot\Operations\ExtensionPackageOperations.ps1

# ── Connect to Dataverse ─────────────────────────────────────────────────────
$connectParams = @{
    environmentUrl = $EnvironmentUrl
    tenantId       = $TenantId
}
if ($ClientId) { $connectParams.clientId = $ClientId }

if ($Interactive) {
    Connect-Interactive @connectParams | Out-Null
}
else {
    if ($CertificateThumbprint) { $connectParams.certificateThumbprint = $CertificateThumbprint }
    elseif ($ClientSecret)      { $connectParams.clientSecret = $ClientSecret }

    Connect @connectParams | Out-Null
}

Write-Host "Connected as: $((Get-WhoAmI).UserId)`n"

# ── Query package record ─────────────────────────────────────────────────────
$records = Get-CsuExtensionPackage -PackageName $PackageName -PackageVersion $PackageVersion

if (-not $records) {
    throw "No CSU extension package found: $PackageName ($PackageVersion)"
}

if ($records.Count -gt 1) {
    throw "Expected 1 record but found $($records.Count) for: $PackageName ($PackageVersion). Data may be inconsistent."
}

$record = $records[0]
$packageId = [System.Guid]::new($record.msprov_commerceextensionassetid)

Write-Host "Package record:"
Write-Host "  ID:          $packageId"
Write-Host "  Name:        $($record.msprov_name)"
Write-Host "  Publisher:   $($record.msprov_publisher)"
Write-Host "  Version:     $($record.msprov_version)"
Write-Host "  SDK Version: $($record.msprov_sdkversion)"
if ($record.msprov_description) {
    Write-Host "  Description: $($record.msprov_description)"
}
Write-Host ""

# ── Download package file ────────────────────────────────────────────────────
$file = Get-CsuExtensionPackageFile -PackageId $packageId -OutputDirectory $OutputDirectory

Write-Host "SUCCESS: CSU extension package downloaded - $PackageName ($PackageVersion) -> $($file.FullName)`n" -ForegroundColor Green

# SIG # Begin signature block
# MIInRwYJKoZIhvcNAQcCoIInODCCJzQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDuuhBjpbxkEq3I
# QkevV8SoJy/SXty0y+sI9mymwbr5yaCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
# yE7XD1dIAAAAAAIdMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBD
# b2RlIFNpZ25pbmcgUENBIDIwMjQwHhcNMjYwNDE2MTg1OTQzWhcNMjcwNDE1MTg1
# OTQzWjB0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYD
# VQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDQvewXxx9gZZFC6Ys1WBay8BJ8kGA4JQnH5CMafqOASlTpK9H8
# o5ZXTXt0caVQTNMUPt445wXYD+dFtaKWTwDn1I52oUSrC9vJin1Gsqt+zyKJL5Dg
# 3eQXbQNR61DmMy20GLTIO3SFed9Rfi/ophgCLGFLDR3r0KvHjwMb/jYWS0celV/4
# Lz27LfAekm8v9E5IXaeiXbAUYZKK090n4CVl3JBtbN+9DtI9SNu/yjvozW52/u7R
# X/Ttpa/KDlpuokZ+Zcbvmtd9ur9gFLvZzh41o9MsE/clQtdaFWGvuo6Jua/ntpgk
# ey3E5/vBFe+MJPG6phdnuo6r57ZudCudiI1bAgMBAAGjggGbMIIBlzAOBgNVHQ8B
# Af8EBAMCB4AwHwYDVR0lBBgwFgYKKwYBBAGCN0wIAQYIKwYBBQUHAwMwHQYDVR0O
# BBYEFH6QuMwqcPG0hQlQ6c5jCtTTLrVeMEUGA1UdEQQ+MDykOjA4MR4wHAYDVQQL
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xFjAUBgNVBAUTDTIzMDAxMis1MDc1NTkw
# HwYDVR0jBBgwFoAUf1k/VCHarU/vBeXmo9ctBpQSCDEwYAYDVR0fBFkwVzBVoFOg
# UYZPaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0
# JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNybDBtBggrBgEFBQcBAQRh
# MF8wXQYIKwYBBQUHMAKGUWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y2VydHMvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNy
# dDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBKTbYOjzwTG/DXGaz9
# s6+fQeaTtDcFmMY+5UyVFCyj7Pv+5i37qfX8lSL/tBIfYQfWsMuBQlfZurJD6r4H
# VJ2CeH+1fgiq8dcHdVKoZ3Sa2qXoX3cq9iS8cVb06B7+5/XJ7I0OxHH9fDsvJ3T3
# w5V/ZtAIFmLrl+P0CtG+92uzRsn0nTbdFjOkLMLWPLAU3THohKRlSEMgFJpPkm5n
# 5UAZ35xX6FWCrDLsSKb555bTifwa8mJBwdlof0bmfYidH+dxZ1FdDxvLnNl9zeKs
# A4kejaaIqqIPguhwAti5Ql7BlTNoJNwxCvBmqW2MQLnCkYN/VVUsR3V2x/rcTNzo
# Bf/Z/SpROvdaA2ZOOd1uioXJt3tdLQ7vHpqpib0KfWr/FWXW10q38VxfCnRQBqzb
# SuztR7nEMuzX7Ck+B/XaPDXd1qh72+QYyB0Z2VzWmO9zsnb9Uq/dwu8LGeQqnyu6
# 7SDGACvnXii2fb9+US492VTnXSnFKyqwgzUyFMtZK1/sHYTv6bG4TtQUygQxTN+Z
# V+aJIlKO2MqZ7bKrAnOzS9m6NgoTdWOq11bTOZwKlIEV/EhV9SWkDmdpR/hPPT2v
# 6TEj4F8PT/zHjRezIU5c/DGlt/VhY/pK0XkJtEyMmmS1BMtjU/rqBZVMIm3dnxQs
# /TBByr+Cf8Z1r7aifQVQ+WSqzjCCBr0wggSloAMCAQICEzMAAAA5O7Y3Gb8GHWcA
# AAAAADkwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRl
# IEF1dGhvcml0eSAyMDExMB4XDTI0MDgwODIwNTQxOFoXDTM2MDMyMjIyMTMwNFow
# VzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEo
# MCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAyNDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBANgBnB7jOMeqlRYHNa265v4IY9fH8TKh
# emHfPINe1gpLaV3dhg324WwH06LcHbpnsBukCDNitryo0dtS/EW6I/yEL/bLSY8h
# KpbfQuWusBPr9qazYcDxCW/qnjb5JsI1s8bNOg3bVATvQVL4tcf03aTycsz8QeCd
# M0l/yHRObJ9QqazM1r6VPEOJ7LL+uEEb73w6QCuhs89a1uv1zerOYMnsneRRwCbp
# yW11IcggU0cRKDDq1pjVJzIbIF6+oiXXbReOsgeI8zu1FyQfK0fVkaya8SmVHQ/t
# Of23mZ4W9k0Ri22QW9p3UgSC5OUDktKxxcCmGL6tXLfOGSWHIIV4YrTJTT6PNty5
# REojHJuZHArkF9VnHTERWoTjAzfI3kP+5b4alUdhgAZ7ttOu1bVnXfHaqPYl2rPs
# 20ji03LOVWsh/radgE17es5hL+t6lV0eVHrVhsssROWJuz2MXMCt7iw7lFPG9LXK
# Gjsmonn2gotGdHIuEg5JnJMJVmixd5LRlkmgYRZKzhxSCwyoGIq0PhaA7Y+VPct5
# pCHkijcIIDm0nlkK+0KyepolcqGm0T/GYQRMhHJlGOOmVQop36wUVUYklUy++vDW
# eEgEo4s7hxN6mIbf2MSIQ/iIfMZgJxC69oukMUXCrOC3SkE/xIkgpfl22MM1itkZ
# 35nNXkMolU1lAgMBAAGjggFOMIIBSjAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYBBAGC
# NxUBBAMCAQAwHQYDVR0OBBYEFH9ZP1Qh2q1P7wXl5qPXLQaUEggxMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU
# ci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2Ny
# bC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0MjAx
# MV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAwTgYIKwYBBQUHMAKGQmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0MjAx
# MV8yMDExXzAzXzIyLmNydDANBgkqhkiG9w0BAQwFAAOCAgEAFJQfOChP7onn6fLI
# MKrSlN1WYKwDFgAddymOUO3FrM8d7B/W/iQ6DxXsDn7D5W4wMwYeLystcEqfkjz4
# NURRgazyMu5yRzQh4LqjA4tStTcJh1opExo7nn5PuPBYnbu0+THSuVHTe0VTTPVh
# ily/piFrDo3axQ9P4C+Ol5yet+2gTfekICS5xS+cYfSIvgn0JksVBVMYVI5QFu/q
# hnLhsEFEUzG8fvv0hjgkO+lkpV9ty6GkN4vdnd7ya6Q6aR9y34aiM1qmxaxBi6OU
# nyNl6fkuun/diTFnYDLTppOkr/mg5WSfCiDVMNCxtj4wPKC5OmHm1DQIt/MNokbb
# H3UGsFP1QbzsLocuSqLCvH09Io3fDPTmscR9Y75G4qX7RTX8AdBPo0I6OEojf39z
# uFZt0qOHm65YWQE69cZM2ueE1MB05dNNgHK9gTE7zKvK/fg8B2qjW88MT/WF5V5u
# vZGtqa9FSL2RazArA+rDPuf6JGYz4HpgMZHB4S6szWSKYBv0VisCzfxgeU+dquXW
# 9bd0auYlOB58DPcOYKdc3Se94g+xL4pcEhbB54JOgAkwYTu/9dLeH2pDqeJZAABV
# DWRQCaXfO5LgyKwKCLYXpigrZYCjUSBcr+Ve8PFWMhVTQl0v4q8J/AUmQN5W4n10
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnjMIIZ3wIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEHKW29P
# 4IqKMyPm6g9FfM8fOmcAl2C4LihQvs/4vujoMEIGCisGAQQBgjcCAQwxNDAyoBSA
# EgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEARrS0e4/IpRLmHlUWbv0/2DLdfLan4HBchei2TNdD
# 0E8ISCfrOR61HyCH9pn1/d8hTKXG1nGzThP4lp6GCLkmOStLYVn81BipKsnpIWU+
# tpLdCmSu/ehyd1XC2YN4oI4gK0yB3lUJIRqoZPeNRH5i31F+U/k9EeHdk/fxUMSw
# yrZSXzk21/BfZFzSrv8ugxfAuTWmLYOBPoBk29RVXgdbTKTmr5e07R7bvHcbUD3r
# drflmid3e3DARHnMc/k+Odku7nPpscIV367GtCepXSF7SfVDoFmrZFfm/E7xHNjX
# FFfVijuEcG9Nl/zZ9xlify2lfv03LPqyIa92OU3+jzmaHKGCF5UwgheRBgorBgEE
# AYI3AwMBMYIXgTCCF30GCSqGSIb3DQEHAqCCF24wghdqAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFQBgsqhkiG9w0BCRABBKCCAT8EggE7MIIBNwIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCDcRyUmZr793YDMIMKcNFT4gxT2EIS/5iEyqShn
# A2b9tgIGahdZ2a9oGBEyMDI2MDYxMzEwMDk1NS43WjAEgAIB9KCB0aSBzjCByzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOkE0MDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIR7TCCByAwggUIoAMCAQICEzMAAAIo8KWH1/PIHkAAAQAAAigw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjYwMjE5MTk0MDA2WhcNMjcwNTE3MTk0MDA2WjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkE0MDAtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAro725P7KnAkkXmWiXwrn9TcEXHO1
# 5J4ROsJC6H5DY9ZsRAIN+astsXBY4I2q7VbwNPVvEB3KcjKlUlzk8TRybJpNKj9g
# gy71ALpVoO2kuaATkaRF9aM959Edpz6nh9CBytcycY8Wh1ttQG7mdGfsDN1mDc5A
# ZXB5lXtN2Ru65ZNvIe9q+T+TBPBRqRZmFuR5e6bCm4CxH62AIrabbbG/rGbAVCPo
# TCpeLiyWKLSsmb9XsDiIpwX0VPEKLIr46H2gXs1H/TXVfohq1od9tVp0rCtwPyZe
# hi7W0ll3CVlC4G8bqp6GzyvmJQd9e+EzFk4F+GFoxu6NDrc/6YxzQigWwe/PHcp4
# S3RmOgdPBPfuEhq0abLcuIiRzsnRwgOTOIucmEcLHbrfoJr8SKU/MjVyXIyQoNLz
# vJr/5xWPVsrb9qpgrQhRYrxlFqlNtP7FHkaKEGRokDiUJ9PeQo94rCLL0T/ClO4T
# fxAyPB1bG/zT8zBS70c560Z49Ezpw4jk1HJ2MJpPl36EtaMLJHAggsB52wtNA+fM
# /N8uyuWSQe+OYXJ+AhNp0d3ukRrK+NsuarbejHc/7OzE5w0tlJlR1l9V/x2Xt1JV
# /II/7ety+dMSD6pEQgRHTNQAzVGkn6PTkIim/249XYmQhk3xA1AQS6KdZoZMCBfN
# n2qZVdm7rGflOJECAwEAAaOCAUkwggFFMB0GA1UdDgQWBBSqyaWM+PLc6Lr1ZAVb
# YQEhaUPdwzAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAkOjXy5q0WoYFbYFoN/Nx
# mktO3x8qHem4XFDjbdrXrfugWjbh9K+wAZFR4XjqcQXa1KzhGFRGiIovXSt3LmSz
# ZqdYlAMf1W5jmWJe8c/rTa4wlqq4NY0JqtKEQfIhOECacDYRj+u6GOYbmCFNA+JY
# Q6Goan4CiZ/9AZPvVCgz8OV5VGJq3hZiZY/WEM3Dz3qfDMQV8Yf2OSO70HkWluUo
# 7Yi0Di0ZN4IL62g7OUn+PTCVevwcMVwtq71HxBV+klA6KKiiBPTYFSEatEWbuzrd
# ItCLPh7zz9IQeisDsTINUlijn07RaVqXaPDCb4Cgh5D6VxM4Kaz/qciB7ju4FUZU
# k7G2ARS4dsiHf4rTOLmC9EftkkgQU6UkkbYaxrhJhJSOQQhzMczIP6Kh0j8GQCAJ
# DNguMcYtEre6jLgPpvmcxWJH6BeNUKEiZ/h46oalmENJv0jvfypyUSSVMDHeU4jJ
# 42fhPwyYlK8ubnYlskKb349oUBSNHY4WoaAFw2s3hHIixdrhJ07q/VH43MDrp/6D
# GPlC37ZzotoyizK63ldPe2pM8/ycaZw4GCVP7YFO30H5YOyKoi/ftNu+vo6EB6Nt
# ZlXmOWA/Cof5FGmOiZvzkzPPBu3r08/6p0bpsaL04zErb6WwBzUYZkk3SD01d9gs
# rsQykv1eWuYsAPn/VYgaPsIwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
# AAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBB
# dXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YB
# f2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKD
# RLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus
# 9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTj
# kY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56
# KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39
# IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHo
# vwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJo
# LhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMh
# XV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREd
# cu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEA
# AaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqn
# Uv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnp
# cjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEw
# CwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/o
# olxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNy
# b3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5j
# cnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+
# TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2Y
# urYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4
# U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJ
# w7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb
# 30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ
# /gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGO
# WhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFE
# fnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJ
# jXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rR
# nj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUz
# WLOhcGbyoYIDUDCCAjgCAQEwgfmhgdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9w
# ZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpBNDAwLTA1RTAtRDk0
# NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAda25hZM0u6gCtTmr9PAFJ4WzSFKggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO3XlqkwIhgPMjAy
# NjA2MTMwODQzMjFaGA8yMDI2MDYxNDA4NDMyMVowdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA7deWqQIBADAKAgEAAgIO9wIB/zAHAgEAAgITdzAKAgUA7djoKQIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIB
# AAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQBIugpYvkCzIydjWacF3s5gE1jq5qoU
# FCS6FhcIz0ZzD84tLvA+9OGbIXP3Lcy3mpdJwP/kIIA7SJg2miBWvfiSwWLS81vD
# U9JvHOdlEu0O4QP40S2WleizQJN4quW3o+Q+fsxJMv1KgZsZgoixxHhr9EjsuJuK
# 3ulxz3OgftqCn4TeyrgHzIoFOHngaKSL4bpNb95cGIs99Yjgrsv3JXo1+QJe/bKU
# pkXGO95HZzxPSVGMX++kqDOxfSRzW/4gXNi9cq8mKeqz3r2OX0odsxc0C4YFo7Cj
# RnUS2Vo4L4ji6zuTrlXptCYlszJ/mX2yZLJwwgUI+p8J4/nSQy5Tcrg0MYIEDTCC
# BAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIo8KWH
# 1/PIHkAAAQAAAigwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsq
# hkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgm2kKkeRBk8MnIk8HNrS00QrhUtuK
# vk77tf022/mgzoQwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCBVsYpGUWBj
# X+KBFWStXk+OR/txkN/6sVe+VcLgbfoi1zCBmDCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAACKPClh9fzyB5AAAEAAAIoMCIEICuoXzXCLr11
# 1oPGcwqNsrWHyUbs135106+vZx8J/2lCMA0GCSqGSIb3DQEBCwUABIICAAbp6QL0
# vKh8ncIAeblfFk3qK1btxWJ4NIAvYQc3aZHiFeIPe0Q+7+OFKVx4bCeEz8c8q7l/
# cPaP1ikInDVGXrC4WQ0fzy6qYY7Q3LqYWHpbXNDDqQsor6M5NJwN4dY/2wis94e4
# qOi6OKiRLDgPlGYKEwKHi5oj1pihEe0C23yhC3944S6WoX81RL/GSSDMRsOOVTB+
# UnGwj27H43mvWBe+ul2ZwEuOxnqb6VpC5nojDx7uxWYdowEVGywQmOPeH0Tzdj88
# hGg7uhGqXAFxNWmuaWkerh/ZbBs4Pm+3Fu7fei519+GC0QB0VNCOVbCrnZIFrImN
# 8HB8v/ZdGKMOmYOm9ZiBmtUeAfG6pGXnJTjGvNbSDJpLvqYr4/stPNmHTwDV6G1u
# I7uZvUadPI7ZL4FrHj77bmzJTiaLOk2CVpXWzqo+grbHyqhdBHwduD1J+1YFolyf
# sRru8jQFSvN500Br0klL8v5G0X8mnxZHbHOUEM58qe2WHe8CF2vB1/BnYnv1McDg
# gDD0CrXEm/EYZQRKiKp2CcRqHwFh2tiOs/LsTCzuu7oRLDuwDj7tfFniGRIKMuqp
# LnYkqPLtgi41GzPSYCG3TkO1KZ+0+Pw4PwrUNzf3rTWUQr+4vuiKO3BNZ22+7jXt
# fZ9I4U22QsFVmrvu4D66ejVKaHAJTLDwMdF5
# SIG # End signature block
