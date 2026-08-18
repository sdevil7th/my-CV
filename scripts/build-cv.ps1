param(
    [string]$OutputName = "Sourav_Das_CV_2026.pdf"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $RepoRoot "build"
$ArtifactsDir = Join-Path $RepoRoot "artifacts"
$PreviewDir = Join-Path $ArtifactsDir "preview"

Set-Location $RepoRoot

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

Write-Host "Building CV with XeLaTeX..." -ForegroundColor Cyan

if (Get-Command latexmk -ErrorAction SilentlyContinue) {
    latexmk `
        -xelatex `
        -interaction=nonstopmode `
        -halt-on-error `
        -outdir="$BuildDir" `
        template.tex

    if ($LASTEXITCODE -ne 0) {
        throw "latexmk failed with exit code $LASTEXITCODE"
    }
}
elseif (Get-Command xelatex -ErrorAction SilentlyContinue) {
    xelatex `
        -interaction=nonstopmode `
        -halt-on-error `
        -output-directory="$BuildDir" `
        template.tex

    if ($LASTEXITCODE -ne 0) {
        throw "First XeLaTeX pass failed with exit code $LASTEXITCODE"
    }

    xelatex `
        -interaction=nonstopmode `
        -halt-on-error `
        -output-directory="$BuildDir" `
        template.tex

    if ($LASTEXITCODE -ne 0) {
        throw "Second XeLaTeX pass failed with exit code $LASTEXITCODE"
    }
}
else {
    throw @"
Neither latexmk nor xelatex was found.

This CV uses fontspec, so it MUST be compiled with XeLaTeX.

Install MiKTeX:
https://miktex.org/download

Then make sure xelatex.exe is available on PATH.
"@
}

$GeneratedPdf = Join-Path $BuildDir "template.pdf"

if (!(Test-Path $GeneratedPdf)) {
    throw "Expected PDF was not generated: $GeneratedPdf"
}

$FinalPdf = Join-Path $ArtifactsDir $OutputName
Copy-Item $GeneratedPdf $FinalPdf -Force

Write-Host ""
Write-Host "Generated PDF:" -ForegroundColor Green
Write-Host $FinalPdf

# Optional page-count validation.
if (Get-Command pdfinfo -ErrorAction SilentlyContinue) {
    $PageLine = pdfinfo $FinalPdf | Select-String "^Pages:"
    if ($PageLine) {
        $Pages = [int](($PageLine.ToString() -split ":")[1].Trim())

        Write-Host "Pages: $Pages"

        if ($Pages -ne 1) {
            Write-Warning "CV is no longer one page."
        }
    }
}

# Optional PNG preview for visual inspection.
if (Get-Command pdftoppm -ErrorAction SilentlyContinue) {
    Remove-Item "$PreviewDir\cv-*.png" -ErrorAction SilentlyContinue

    pdftoppm `
        -png `
        -r 160 `
        $FinalPdf `
        "$PreviewDir\cv"

    Write-Host "Preview images:"
    Write-Host $PreviewDir
}
elseif (Get-Command magick -ErrorAction SilentlyContinue) {
    Remove-Item "$PreviewDir\cv-*.png" -ErrorAction SilentlyContinue

    magick `
        -density 160 `
        $FinalPdf `
        "$PreviewDir\cv-%02d.png"

    Write-Host "Preview images:"
    Write-Host $PreviewDir
}

Write-Host ""
Write-Host "CV build complete." -ForegroundColor Green
