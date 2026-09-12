param(
    [Parameter(Mandatory = $true)]
    [string]$Folder
)

$ErrorActionPreference = "Stop"

$Manifest = Join-Path $Folder "SHA256SUMS.txt"

if (-not (Test-Path $Manifest)) {
    throw "SHA256SUMS.txt not found: $Manifest"
}

$Lines = Get-Content $Manifest |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }

$Passed = 0
$Failed = 0
$Missing = 0

Write-Host ""
Write-Host "BB保你大 SHA-256 verification"
Write-Host ""

foreach ($Line in $Lines) {

    if ($Line -notmatch '^([a-fA-F0-9]{64}) \*(.+)$') {
        Write-Warning "Invalid manifest entry: $Line"
        continue
    }

    $ExpectedHash = $matches[1].ToLower()
    $FileName = $matches[2]

    $FilePath = Join-Path $Folder $FileName

    if (-not (Test-Path $FilePath)) {

        Write-Host "[MISSING] $FileName"

        $Missing++
        continue
    }

    Write-Host -NoNewline "[CHECK]   $FileName ... "

    $ActualHash = (
        Get-FileHash `
            $FilePath `
            -Algorithm SHA256
    ).Hash.ToLower()

    if ($ActualHash -eq $ExpectedHash) {

        Write-Host "OK"
        $Passed++
    }
    else {

        Write-Host "FAILED"

        Write-Host "          Expected: $ExpectedHash"
        Write-Host "          Actual:   $ActualHash"

        $Failed++
    }
}

Write-Host ""
Write-Host "============================================"
Write-Host " Verification complete"
Write-Host "============================================"
Write-Host ""
Write-Host "PASSED:  $Passed"
Write-Host "FAILED:  $Failed"
Write-Host "MISSING: $Missing"
Write-Host ""

if (($Failed -eq 0) -and ($Missing -eq 0)) {

    Write-Host "All files passed SHA-256 verification."
    exit 0
}
else {

    Write-Host "Integrity verification FAILED."
    exit 1
}
