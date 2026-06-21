function Set-FileColumnInChunks {
    param (
        [Parameter(Mandatory)]
        [string]
        $setName,

        [Parameter(Mandatory)]
        [System.Guid]
        $id,

        [Parameter(Mandatory)]
        [string]
        $columnName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [System.IO.FileInfo]
        $file
    )

    $uri = '{0}{1}({2})' -f $baseURI, $setName, $id
    $uri += '/{0}?x-ms-file-name={1}' -f $columnName, $file.Name

    $chunkHeaders = $baseHeaders.Clone()
    $chunkHeaders['x-ms-transfer-mode'] = 'chunked'

    $InitializeChunkedFileUploadRequest = @{
        Uri     = $uri
        Method  = 'Patch'
        Headers = $chunkHeaders
    }

    Invoke-RestMethod @InitializeChunkedFileUploadRequest -ResponseHeadersVariable rhv | Out-Null

    $locationUri = $rhv['Location'][0]
    $chunkSize = [int]$rhv['x-ms-chunk-size'][0]

    Write-Host "Chunk size: $([Math]::Round($chunkSize / 1MB, 2)) MB"

    $stream = [System.IO.File]::OpenRead($file.FullName)
    try {
        $fileSize = $stream.Length
        $totalChunks = [Math]::Ceiling($fileSize / $chunkSize)
        $currentChunk = 0

        for ($offset = 0; $offset -lt $fileSize; $offset += $chunkSize) {

            $currentChunk++

            $count = if (($offset + $chunkSize) -gt $fileSize) {
                $fileSize - $offset
            }
            else {
                $chunkSize
            }

            $buffer = [byte[]]::new($count)
            [void]$stream.Read($buffer, 0, $count)

            $lastByte = $offset + ($count - 1)

            $range = 'bytes {0}-{1}/{2}' -f $offset, $lastByte, $fileSize

            $contentHeaders = $baseHeaders.Clone()
            $contentHeaders['Content-Range'] = $range
            $contentHeaders['Content-Type'] = 'application/octet-stream'
            $contentHeaders['x-ms-file-name'] = $file.Name

            $UploadFileChunkRequest = @{
                Uri     = $locationUri
                Method  = 'Patch'
                Headers = $contentHeaders
                Body    = $buffer
            }

            Invoke-RestMethod @UploadFileChunkRequest | Out-Null

            Write-Host "Uploaded chunk $currentChunk/$totalChunks"
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-FileColumnInChunks {
    param (
        [Parameter(Mandatory)]
        [string]
        $setName,

        [Parameter(Mandatory)]
        [System.Guid]
        $id,

        [Parameter(Mandatory)]
        [string]
        $columnName,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $outputDirectory
    )

    $uri = '{0}{1}({2})/{3}/$value' -f $baseURI, $setName, $id, $columnName

    $chunkSize = 4 * 1024 * 1024  # 4 MB

    # Use minimal headers for file download (OData headers cause 400 on file endpoints)
    $downloadHeaders = @{
        'Authorization' = $baseHeaders['Authorization']
        'Range'         = 'bytes=0-{0}' -f ($chunkSize - 1)
    }

    $InitialDownloadRequest = @{
        Uri     = $uri
        Method  = 'Get'
        Headers = $downloadHeaders
    }

    $response = Invoke-WebRequest @InitialDownloadRequest

    $fileName = $response.Headers['x-ms-file-name'][0]
    $fileSize = [long]$response.Headers['x-ms-file-size'][0]

    Write-Host "Downloading file: $fileName ($([Math]::Round($fileSize / 1MB, 2)) MB)"
    Write-Host "Chunk size: $([Math]::Round($chunkSize / 1MB, 2)) MB"

    $totalChunks = [Math]::Ceiling($fileSize / $chunkSize)
    $currentChunk = 1

    $outputFilePath = Join-Path $outputDirectory $fileName

    # Avoid overwriting existing files by appending an incrementing number.
    if (Test-Path $outputFilePath) {
        $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $counter   = 1
        do {
            $outputFilePath = Join-Path $outputDirectory ("{0} ({1}){2}" -f $baseName, $counter, $extension)
            $counter++
        } while (Test-Path $outputFilePath)
    }

    $stream = [System.IO.File]::Create($outputFilePath)
    try {
        $stream.Write([byte[]]$response.Content, 0, $response.Content.Length)

        Write-Host "Downloaded chunk $currentChunk/$totalChunks"

        $offset = $response.Content.Length

        while ($offset -lt $fileSize) {

            $currentChunk++

            $lastByte = [Math]::Min($offset + $chunkSize - 1, $fileSize - 1)

            $chunkHeaders = @{
                'Authorization' = $baseHeaders['Authorization']
                'Range'         = 'bytes={0}-{1}' -f $offset, $lastByte
            }

            $DownloadChunkRequest = @{
                Uri     = $uri
                Method  = 'Get'
                Headers = $chunkHeaders
            }

            $response = Invoke-WebRequest @DownloadChunkRequest

            $stream.Write([byte[]]$response.Content, 0, $response.Content.Length)
            $offset += $response.Content.Length

            Write-Host "Downloaded chunk $currentChunk/$totalChunks"
        }
    }
    finally {
        $stream.Dispose()
    }

    Write-Host "File saved to: $outputFilePath"

    return Get-Item $outputFilePath
}
# SIG # Begin signature block
# MIInRAYJKoZIhvcNAQcCoIInNTCCJzECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB5Qs/8OQ7PkXRp
# G8MTN7VFnOxqW8zfjWBkuQgmOeGpBKCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghngMIIZ3AIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICxniBSb
# MP1+S4bTX6NfZFlK7a1Qqa9pj3crnRhmS4EfMEIGCisGAQQBgjcCAQwxNDAyoBSA
# EgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEASkvubOa187FlHfca7jyK8KQC0untKCn/XJvQ55GM
# Kv+ZrpgpzjeT2mAT6HN/G89aMf3ROgZKmQSeOfXpGBcDfNk+wvt51TbmqndeDKNv
# lEwANQ0mBzEbRPaSFF4fGMV3T/uMnUfgI7EbSvKnoQBWrN7xnugu0UlSXSKEfgHr
# VHAi77enB8tPubLVrRy1b2WKM7GIxylsIDrf3EsubGckPV07Bxrds7/Bfi6NeIuK
# GRcppB7RtnP89jeM8wjs+fmyQYGVIvPv5DXlhN9DWYopBYFUljV/NTRM2flr6hbV
# gI+5hUABztVntoIUsRfER7KexjZl8OXQs5BlWyFuvptiraGCF5IwgheOBgorBgEE
# AYI3AwMBMYIXfjCCF3oGCSqGSIb3DQEHAqCCF2swghdnAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFQBgsqhkiG9w0BCRABBKCCAT8EggE7MIIBNwIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCC7qAcYppS2YqL7PJcGnqj0pxNtWxiPDWO5MZoz
# Lh/luwIGajF2fp4AGBEyMDI2MDYyMTEwMTIzMi44WjAEgAIB9KCB0aSBzjCByzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdGMDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIR6jCCByAwggUIoAMCAQICEzMAAAIeo6ykbjlvfEkAAQAAAh4w
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjYwMjE5MTkzOTQ5WhcNMjcwNTE3MTkzOTQ5WjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdGMDAtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEApdE47Ww8LEexXvGnOqJebNc4bU6n
# dgFqXIUIS6fRuZpkjNtzeX8kBgkNQ9OqzgNz4Fyhfu+r17zgrNlbC79aMI+JhxMh
# KoqvBiecgvv0DWEaWTwPHuzoHpMwzukv+L8v40zGG6d64bhYiigs01jkLXRXBfg9
# JN+vSO6ZvxNO0sjTBpLjXeZY+UifdVKhbmX4zAenENsIe+5rYkVFXY+d8o3Tao/h
# kJfmGs9vQY685+1NZZ/iaS5Z29MXRpmaCDymW8AVXFrci+LsoTC+0kk5ojn1l1Po
# PsjZdAnaCxi/C7VhxIvBbLkz3knUqpnjK7y2hJom01U0uL0EGPDT52+riOcuojVf
# bwRXJvC1P5Q04xk6j2u1AU+IHX+SZt8GK3whWeD/4+TKKk9CTjXGudI7eExiPdEo
# oV2gxGKpNt0tCCWd1JFKbpA0U4yu9dwSMpH38cgajHkKnztM71n1Mewa5lKboEHM
# Pffg8S5doH/rkBKUZp5W61SfXb1vXbOH6hDzdoxtEMBdTwUoJTXFdUqamSorUIAR
# ksLv/NgCs7aAh8GER0TcM8E1Xv9SjU75qgHeFIHrOMsDh9NoWmoE/MGGPDnVnYyp
# 95NOdsPpJnNFAtBfolV0xmSDMb6PYgWUKF3oc0bVif1TrSrwskt3LCsze60rVicI
# 0ls+nbTn9JfsrS0CAwEAAaOCAUkwggFFMB0GA1UdDgQWBBTmChaa6gQdCWZiXBQu
# HDz5nheCZDAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEApKGQeTZyVRW+cCno0aJ5
# OdfGtkwTWKSnATLXy+gUtAEWgATjBmC5TzboSNR8JnpT/YV96Kt02hJv3A5JMzUA
# Mw3nT4KESNke/vKaDUlrx1xALO0mTg5vceyqpQZDWTPXseF2NcjZlTgJlg40a+4y
# o2okG57X+xAuBjYpMRhmlVjo32Ld0PV9K/yrPCgZW8w0fc4wP0wnLUeHKNVqVNWU
# SxawfW5fHUcbG58k9qkONRO3U9dkd9HiBlM4hLORjftulf6L1zottHSYjNd4WFr8
# tTTSQIZCjpSwdTjbp3en34T3VHB1rLvFfpUdGmpDFeuB6g2y7pmawjcFKH1cd8TJ
# PBeLQmCbUMS08sHN9LGQA9UtrAtfefceiosQPqeNRS1JfIOuKB8t232Jx+cXeCTg
# YEKGqp3Ro3HLca/vBJJ44Ssq4AM603CiyW1Hs4KMnvG6wiyfsujwKBI6V0ZEmAFP
# MH0N2FkXJOgC8KFe1Ip/Pq6RkEm14RenNXUxWpF5goQpbneCAA2P7eiUZCftOhcy
# /ow3fCi1fEI++yX4rk4jyBuRv8ZZxqGRXF/ssgbQ782ROPHfmPh2FHf3L4R9RSpe
# wB/uQMqLaiUhZrzPwbmEcdgdtGrFV4pVdpNiWzTtyxgs90PnaRJc8LHya5GtTf4H
# rZmu31qaMLDb6CGhEL42nfEwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
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
# WLOhcGbyoYIDTTCCAjUCAQEwgfmhgdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9w
# ZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RjAwLTA1RTAtRDk0
# NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAg/0DZCgyFuFSBe496Itqm60dGv+ggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO3h4xcwIhgPMjAy
# NjA2MjEwNDEyMDdaGA8yMDI2MDYyMjA0MTIwN1owdDA6BgorBgEEAYRZCgQBMSww
# KjAKAgUA7eHjFwIBADAHAgEAAgIWbjAHAgEAAgISjDAKAgUA7eM0lwIBADA2Bgor
# BgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAID
# AYagMA0GCSqGSIb3DQEBCwUAA4IBAQA6lqVuvxSh4/+4B+DqRHM41DjSz6ePvfzi
# /hIPfWhDyBHWzJ9Al19c5iBNtUryLe1fPea3vVu29rqE6aRntdL3vzU6TZMGxQEZ
# MoctJxSXl/FKYDrh5Yf8yCBszyz4QhJbauSs1tZUs3r52JymvTJDRUpEsAWhd8w8
# UjrSwsbMwQGPaoTpmkPIB6UWMwaYbOpuVy8kpL6NnZAk6NO4um+cIZ83PVQYA+xK
# RB+c9UPtgc9NgLvGSTv3rNsxixM7Wz3sXi+PP7BtdeH/0S3l+EnaBdVJRhuzDak3
# InvfvLm85E2m6sAHD52LaaQYUzdlmo1NhX04sTgs2Kox8cJANXuBMYIEDTCCBAkC
# AQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIeo6ykbjlv
# fEkAAQAAAh4wDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG
# 9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgnjW1wpEivPgRMWeH6R5QxpmeIvReDG48
# JM5dlgsqaI0wgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCAvgV1q8/YHjIDP
# Ab5/G6sR44R1ydvRAYsyEyMNAfbzgjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAACHqOspG45b3xJAAEAAAIeMCIEIN6W9VgtE31RV/w0
# pwlx45AHBYpGrxMqHsadmLUM3Xf3MA0GCSqGSIb3DQEBCwUABIICAABdN7aaf1oU
# GA8ac5svoSfMlBd4y5AaW2NzH3u/IWZFdQ6JaPQGuZHTLqofs6QfGuTqiKHXwkt0
# 8MEefuCxrXWt61M8A5baQoCy9GItWszHZuPClINAjGRd016nTEcGwtYWqVEH1N20
# FZEpY0oi42Oyj+iJJTzj5XfU7CdYi9Bi7HaKJYaFup8ge3P7mlxDQ6aCgg5duW3T
# 15/kBbYaV0gHGYvlWx+DxOqS7YlBifcYxXZDFuMI9Et715YHl75YqMgPCjD+ewtG
# ikhH/NbLrUqGU+ZwfXqwkALMjA3Zp6qs1+TrD+XiDqxR47Yx4jFwRZ+/C2ijpIFw
# uJ1YiIVeKI2k6epqE788AvVdevALUJIcndo3FC5R4VNcbRLuGiBgHrNxfdchBAOb
# SH+aeTE+NrprVzyKnLUUPpOYGPGdMIDGTdEGkhMWG5EcGAD2PPeck7OvpTpZwtzs
# wdHCoz9fKxITf1iGM9PoIorFNhF5SGY3lsBl4xGuJH9NV04C8joOpbEiwJj6QBSI
# 0D7WrK1fpwxg1iZpk9hhQhKn40I+HKCcZGFxo8bFj8qKHW2vd8ukfynOxdxGkMV5
# 5jIA2exg+id4YwZWta9iuxyYgvR/zHNz6/HcFQOtdk+7dfkjpotzpwvbymzxIUF8
# 5qQ9gVd5feMP7T/M/rIxZu+LACETru58
# SIG # End signature block
