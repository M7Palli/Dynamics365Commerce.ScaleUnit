. $PSScriptRoot\TableOperations.ps1
. $PSScriptRoot\FileOperations.ps1

function New-CsuExtensionPackage {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackagePublisher,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageVersion,

        [Parameter()]
        [String]
        $SdkVersion,

        [Parameter()]
        [ValidateSet('Valid', 'Invalid')]
        [String]
        $ValidationStatus,

        [Parameter()]
        [String]
        $PackageDescription
    )

    try {
        $body = @{
            msprov_name       = $PackageName
            msprov_publisher  = $PackagePublisher
            msprov_version    = $PackageVersion
            msprov_sdkversion = $SdkVersion
            msprov_assettype  = 0 # CSU Extension Package
        }

        # Add optional fields if provided
        if ($ValidationStatus) {
            $statusValue = switch ($ValidationStatus) {
                'Valid'   { 202570000 }
                'Invalid' { 202570001 }
            }
            $body['msprov_commerceextensionasset_validationstatus'] = $statusValue
        }

        if ($PackageDescription) {
            $body['msprov_description'] = $PackageDescription
        }

        Write-Host "Creating CSU extension package record: $PackageName ($PackageVersion)"

        $recordId = New-Record -setName 'msprov_commerceextensionassets' -body $body

        Write-Host "Successfully created CSU extension package record with ID: $recordId`n" -ForegroundColor Green
        return $recordId
    }
    catch {
        Write-Error "Failed to create CSU extension package record $PackageName ($PackageVersion): $($_.Exception.Message)`n"
        throw
    }
}

function Set-CsuExtensionPackageFile {
    param (
        [Parameter(Mandatory)]
        [System.Guid]
        $PackageId,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [String]
        $FilePath,

        [Parameter()]
        [String]
        $ColumnName = 'msprov_payload'
    )

    try {
        $fileInfo = Get-Item -Path $FilePath
        $fileSizeMB = [Math]::Round($fileInfo.Length / 1MB, 2)

        Write-Host "Uploading CSU extension package file: $($fileInfo.Name) ($fileSizeMB MB)"

        Set-FileColumnInChunks -setName 'msprov_commerceextensionassets' `
            -id $PackageId `
            -columnName $ColumnName `
            -file $fileInfo

        Write-Host "Successfully uploaded CSU extension package file to record: $PackageId`n" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to upload CSU extension package file: $($_.Exception.Message)`n"
        throw
    }
}

function Get-CsuExtensionPackage {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageVersion
    )

    try {
        Write-Host "Querying CSU extension package: $PackageName ($PackageVersion)"

        $escapedPackageName = $PackageName.Replace("'", "''")
        $escapedPackageVersion = $PackageVersion.Replace("'", "''")
        $filter = "?`$filter=msprov_name eq '$escapedPackageName' and msprov_version eq '$escapedPackageVersion' and msprov_assettype eq 0"
        $response = Get-Records -setName 'msprov_commerceextensionassets' -query $filter

        $records = $response.value

        if (-not $records -or $records.Count -eq 0) {
            Write-Host "No CSU extension package found: $PackageName ($PackageVersion)" -ForegroundColor Yellow
            return $null
        }

        Write-Host "Found $($records.Count) CSU extension package record(s): $PackageName ($PackageVersion)`n" -ForegroundColor Green
        return $records
    }
    catch {
        Write-Error "Failed to query CSU extension package $PackageName ($PackageVersion): $($_.Exception.Message)`n"
        throw
    }
}

function Get-CsuExtensionPackageFile {
    param (
        [Parameter(Mandatory)]
        [System.Guid]
        $PackageId,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [String]
        $OutputDirectory,

        [Parameter()]
        [String]
        $ColumnName = 'msprov_payload'
    )

    try {
        Write-Host "Downloading CSU extension package file from record: $PackageId"

        $file = Get-FileColumnInChunks -setName 'msprov_commerceextensionassets' `
            -id $PackageId `
            -columnName $ColumnName `
            -outputDirectory $OutputDirectory

        Write-Host "Successfully downloaded CSU extension package file: $($file.Name)`n" -ForegroundColor Green
        return $file
    }
    catch {
        Write-Error "Failed to download CSU extension package file: $($_.Exception.Message)`n"
        throw
    }
}

# SIG # Begin signature block
# MIInRwYJKoZIhvcNAQcCoIInODCCJzQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCkH0lDp4vhyVxg
# HqQpKbs8RRWIikHX+xG/HV6lxe2g+KCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEmTHlnv
# A3iWfg047E+x1uVZorkKLLnmEix29tMQH/fnMEIGCisGAQQBgjcCAQwxNDAyoBSA
# EgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEAb8rTE/kWpDvFU6Bh2nXAM3KgX8/ViXlCPpScmUF7
# qL9EPRq1/GuRo3P8rEbHdbE05Fs9eSQCH1R6facEaCOTRfcUnGNUUsPG85W7898E
# WseOM2O7enlpoIaHybFyHUf+lmiVWs2np5oudOufNVGNlqpaMx2iFiBm6hwDRItz
# Zvpomyc4ug2l/uar3WdJmitAU0P+7XCmRGYxWONkIO39dj4GC8bAH9oTRmgSq+5M
# Mxz4UB8t18Z0fOyUYxMRk88k6Woyh6jYIayDEcJzAZi5dtWdvJS1aK8Vdukt2qKD
# iXjorxocq6ma3zjZ84QRaT332b8xwaG8ADQmVdvytrGcUKGCF5UwgheRBgorBgEE
# AYI3AwMBMYIXgTCCF30GCSqGSIb3DQEHAqCCF24wghdqAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFQBgsqhkiG9w0BCRABBKCCAT8EggE7MIIBNwIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCDKgcEVRHu4nBSa6Iohxs0CaKwQe+3nHhkkE7a2
# 3YjLPQIGahdRXY8GGBEyMDI2MDYwODEwMTEyMy45WjAEgAIB9KCB0aSBzjCByzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOkUwMDItMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIR7TCCByAwggUIoAMCAQICEzMAAAIpDtVkKrSX8hoAAQAAAikw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjYwMjE5MTk0MDA3WhcNMjcwNTE3MTk0MDA3WjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkUwMDItMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAniLRauM9aAmEplGZqWA7GyVhLvvt
# W23PzM+z2tyNGV+RDjfloqwdBb5xpchUVMpczuUyV2X1PEBTzlPeT9WNTmfCfqrg
# ORvgFkgTq/+PLHJdLPUQaaoEzKv5W8qgc+AjJr1UdkHrwIFaeGtYW5jpvRu2Fnsu
# vDeRea0g2FdMDJYOCMvGEbhYETdngaVV7fSLxWhZgZ0C2X6Ntimdy/D1hB1IV1OX
# SzkmaE36qkPwfnXluegAjJ5x4z8WbvrMx4WTC1KzFk4LPSewp/A7XpXCo/WjPtGa
# u7ZEgxwq8KOngkn8N3JZLV0Ua3ZrHHGpfEQg4jRRYGbMqcBdmhgBepIONfkJfrYV
# 6ZzjFB+JjwgCWVqdMw1qMLCv2KOYxy9aU/wIGy9xaAMuHG4TiOD29XkBRvo0+7JE
# thf2/mQAlANRA2fN9CvgbtMsPhaUhsvLaXdbM5N3FGIyKcyBuM96BTZokiTfGHTX
# eEh7BEeQ5LOW8Yim6b5n6zgN/Y02+xFtk0+8kloCSEn703s7i5kLE1UszbL2qVZR
# 4RNswag8ONPZ7zrYrQhW54YVzX2rc29vhn9rV9rOmAWtedQgv/Pnpib73oF21jbn
# c2LfHBUaJtD2fnyUYYQX3Uqgqq/EHjhifFWJZsRV6sdUnQ0pEwkoKbLJBqmcIf+r
# pgNYOC+83hgTZ4ECAwEAAaOCAUkwggFFMB0GA1UdDgQWBBQnTUWki/QFvEL2kNtV
# o0QFyjeDOzAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAPcHO9pX/3Mw4adPU9zxg
# DDkIcZf8dOI6RO7d/RXqkEp9lKeg1c4YMJ8wqmNzSIS7VGlq3ezcb64WQ3GvieMc
# 760UDTx3kUKZyVXh7Mk7ud4EwZVAdU0SOjp2bfwFZkfaDCfzQTqgfnfkjm/D8es0
# YEcJOtrBZDpAeZYoPwzJ2BHkf2plvR3aPL13Cpmmvw20jgB0nX2RbfoqjGXzZZBD
# p+9f0QCkzb+EKav9hYXIzDJkpCIbIQXQVQdFY5pMBX4VVH+U07iyfbA0eBMgrzmS
# dweoOyMOlo0McnI8JH87FTE6X7rCeUsHThy/Mhj1mTnj48GvCEl1rOpIlSv+ktPy
# VW9S6cacmCkREI51P+TnnCrdjl5R3cBVma8AIvfET2WuhBMXG/yxi39dLTR47tXk
# 5aIWNI8zWUNAQ4ErjGYDFPvBBI7TEDCA55TxhFDjeyx1xx9Ci9BQNNTxFlWSq6/y
# 1Drrg0zRc8OeNxTzKeIJAiBZSnUbnIkdSFzpPl7Huq4/bSRWIFZ/uOAR6Ltl0HuU
# V99Hn9wEFmtJschg6icxrFd1+fmzUHjFfPIlrpST6ubIJxhvTvx9fxx+B7DvWShl
# /1qyaUJhbkK0zkePV473mgtMWhZhrDYPkYW7Q+ak5J/iEg78NCCfxP1VzXc/8loK
# Jeq+dO4U/LADLqZ4ZBdrsNQwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
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
# ZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpFMDAyLTA1RTAtRDk0
# NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAt7/YkjttsaG+2cTeXVwhKvvSL/+ggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO3Q94owIhgPMjAy
# NjA2MDgwODEwNTBaGA8yMDI2MDYwOTA4MTA1MFowdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA7dD3igIBADAKAgEAAgITawIB/zAHAgEAAgIT1jAKAgUA7dJJCgIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIB
# AAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQCmelY+1dR1wmPNiEaFmnlmvzCsXqR/
# F0NNS8WeadW9mQ6S4FyVYMbsIEvDT85+kUMrN4tIBHX0AhRX6aKqQYJSt3GM+L5H
# Zvi/jZa4HtL1pSFf5chxzC0A7H094QIySJvAulGl/i87gn49MirEsK0/uNJO7VS1
# hKaU/HqBvIjyZgi8UL7qsLwyrM58XlfL6SAvCgdXtGuurslLHCltk0YajaI0CI+G
# r6bXlZAmFGPcEg39lntATapllIbthKB05+PKtv2WZfiXv5qipuWc1xoaAXqWqgt7
# eDkrVFAgQePBKOx+fpMd7o30TCaQ2c/ba65p5Y+P7CHt2w7xJF2NtMRZMYIEDTCC
# BAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIpDtVk
# KrSX8hoAAQAAAikwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsq
# hkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgbVAvcVkmXgv5PL+Ds8h+W79lZST3
# koKAgkC/qwMXNlowgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCC3yj3xIrbw
# /5UrxLpsaj5JHjhLYJJihRFTLnpfaDq6kjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAACKQ7VZCq0l/IaAAEAAAIpMCIEIOaGsMClkdUB
# V8hMcNMYjZYWN85EQ3Fyi4DW3mGS4GW5MA0GCSqGSIb3DQEBCwUABIICADO00BgZ
# 2tF91VZ3c36FUOAVbD3oAVSDCwIaPI/MOHZ2ig5uQ/eHg2unh6vBbivLp490mMwA
# pbWiIXYno3lozriTaVuBQb5apUNfO+/jWddtIsjGAuOrrhKw1z0pNllhyD4aonWV
# Vq9LhMeHhGLLyoesEvH0IINCC3B58rdsOnEyn+yTMmGqZW+abEdM+2TJ1PqAgYVO
# WmbNd77X7OzVtBpjezzz+kRb0fupqr5tKVGemr/J0Gwpj7OZB+5Zk+ZBnPBLzwdx
# QHqmR7SwiuptOi/lCu+f6upwTE4/H89IfrnlwwzhCKMbW1OD2u7fWnluR7XX2eqb
# DP852NCg5nbf+obqv56xOmqsKjzcySjjVq4515W6aLt3c9EJ3xXhz8+99aQZsCTa
# cVevt+5YqI0+2gkB+dbhiEvSlyUKoHS4e1hIGT51tYPm0mIuakXhc5mChgs/1o9A
# 45yWb0tvhW7T3rssK7cReCT0b4VKxlE8sVaLFD67IGmaCUy3REfW7WDtJqa1+hKy
# NkDXIL7z4FrlJOwZSAJLkG3mcHrmz6z4fKv/qTAXHu8ozVw0yk3iz+uG37aS+WZr
# d/djEORh5nCqlBQTKPfqMaDnqzl/CWS4j6Pi5NA2W8rHoTLT2KNxR2q1R2c8r8gT
# 6OEu/YS7X4+P8RuSdvqjEXz5+lYZHTmCoh4t
# SIG # End signature block
