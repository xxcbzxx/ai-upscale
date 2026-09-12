param(
    [Parameter(Mandatory = $true)]
    [string]$Folder
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Folder)) {
    throw "Directory not found: $Folder"
}

$Manifest = Join-Path $Folder "SHA256SUMS.txt"

$Files = Get-ChildItem $Folder -Filter "EP*-1080p.mkv" |
    Sort-Object {
        if ($_.BaseName -match '^EP(\d+)') {
            [int]$matches[1]
        }
        else {
            9999
        }
    }

Write-Host ""
Write-Host "Found $($Files.Count) episodes."

if ($Files.Count -ne 52) {
    Write-Warning "Expected 52 episodes but found $($Files.Count)."
}

$Lines = foreach ($File in $Files) {

    Write-Host "SHA256 $($File.Name)"

    $Hash = Get-FileHash `
        $File.FullName `
        -Algorithm SHA256

    "$($Hash.Hash.ToLower()) *$($File.Name)"
}

$Lines |
    Set-Content `
        $Manifest `
        -Encoding UTF8

Write-Host ""
Write-Host "============================================"
Write-Host " SHA-256 manifest created"
Write-Host "============================================"
Write-Host ""
Write-Host "Files:    $($Files.Count)"
Write-Host "Manifest: $Manifest"
