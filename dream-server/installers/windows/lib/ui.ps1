# ============================================================================
# Dream Server Windows Installer -- UI Helpers
# ============================================================================
# Part of: installers/windows/lib/
# Purpose: Colored output, phase headers, progress, banners
#
# Matches the CRT narrator voice from installers/lib/ui.sh
# ============================================================================

function Write-DreamBanner {
    $banner = @"

    ____                              ____
   / __ \________  ____ _____ ___   / ___/___  ______   _____  _____
  / / / / ___/ _ \/ __ `/ __ `__ \  \__ \/ _ \/ ___/ | / / _ \/ ___/
 / /_/ / /  /  __/ /_/ / / / / / / ___/ /  __/ /   | |/ /  __/ /
/_____/_/   \___/\__,_/_/ /_/ /_/ /____/\___/_/    |___/\___/_/

"@
    Write-Host $banner -ForegroundColor Green
    Write-Host "  DREAMGATE Windows Installer v$($script:DS_VERSION)" -ForegroundColor White
    Write-Host "  One command to a full local AI stack." -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Phase {
    param(
        [int]$Phase,
        [int]$Total,
        [string]$Name,
        [string]$Estimate = ""
    )
    $elapsed = ((Get-Date) - $script:INSTALL_START).ToString("hh\:mm\:ss")
    Write-Host ""
    Write-Host "  DREAMGATE SEQUENCE [$elapsed]" -ForegroundColor DarkGray -NoNewline
    Write-Host "  PHASE $Phase/$Total" -ForegroundColor White -NoNewline
    Write-Host " -- $Name" -ForegroundColor Green
    if ($Estimate) {
        Write-Host "  Estimated: $Estimate" -ForegroundColor DarkGray
    }
    Write-Host ("  " + ("-" * 60)) -ForegroundColor DarkGray
}

function Write-AI {
    param([string]$Message)
    Write-Host "  > $Message" -ForegroundColor Green
}

function Write-AISuccess {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-AIWarn {
    param([string]$Message)
    Write-Host "  [!!] $Message" -ForegroundColor Yellow
}

function Write-AIError {
    param([string]$Message)
    Write-Host "  [XX] $Message" -ForegroundColor Red
}

function Write-Chapter {
    param([string]$Title)
    Write-Host ""
    Write-Host ("  " + ("=" * 60)) -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor White
    Write-Host ("  " + ("=" * 60)) -ForegroundColor DarkGray
}

function Write-InfoBox {
    param(
        [string]$Label,
        [string]$Value
    )
    Write-Host "  $Label" -ForegroundColor DarkGray -NoNewline
    Write-Host " $Value" -ForegroundColor White
}

function Show-ProgressDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Label = "Downloading"
    )
    Write-AI "$Label..."
    # Use curl.exe (ships with Windows 10+) for resume-capable download with progress
    # Notes:
    # - --fail makes HTTP 4xx/5xx return non-zero (prevents saving HTML error pages as "successful" downloads)
    # - --retry reduces transient network failures
    $partFile = "$Destination.part"
    & curl.exe -C - -L --fail --retry 3 --retry-delay 2 --retry-all-errors --progress-bar -o $partFile $Url
    $curlExit = $LASTEXITCODE
    if ($curlExit -eq 0 -and (Test-Path $partFile)) {
        Move-Item -Path $partFile -Destination $Destination -Force
        Write-AISuccess "$Label complete"
        return $true
    } else {
        $curlErrors = @{ 6="Could not resolve host"; 7="Connection refused"; 18="Partial transfer"; 22="HTTP error"; 28="Timeout"; 35="SSL error"; 56="Network failure" }
        $hint = $(if ($curlErrors.ContainsKey($curlExit)) { " ($($curlErrors[$curlExit]))" } else { "" })
        Write-AIError "$Label failed (curl exit code: $curlExit$hint)"
        Write-AI "Re-run the installer to resume the download."
        return $false
    }
}

function Test-ZipFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{ Valid = $false; Reason = "File not found" }
    }

    try {
        $fi = Get-Item -Path $Path
        if ($fi.Length -lt 1024) {
            return @{ Valid = $false; Reason = "File too small to be a valid zip" }
        }

        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $header = New-Object byte[] 4
            $read = $fs.Read($header, 0, 4)
            if ($read -lt 2 -or $header[0] -ne 0x50 -or $header[1] -ne 0x4B) {
                return @{ Valid = $false; Reason = "Missing ZIP header (PK)" }
            }
        } finally {
            $fs.Close()
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue | Out-Null
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            if ($zip.Entries.Count -lt 1) {
                return @{ Valid = $false; Reason = "Zip has no entries" }
            }
        } finally {
            $zip.Dispose()
        }

        return @{ Valid = $true; Reason = "OK" }
    } catch {
        return @{ Valid = $false; Reason = $_.Exception.Message }
    }
}

function Expand-ZipSafe {
    param(
        [string]$ZipPath,
        [string]$DestinationPath,
        [string]$Label = "Extracting"
    )

    Write-AI "$Label..."
    try {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
        return $true
    } catch {
        Write-AIError "$Label failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-ZipAsset {
    param(
        [string]$Url,
        [string]$ZipPath,
        [string]$DestinationPath,
        [string]$Label,
        [int]$MaxAttempts = 2
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (Test-Path $ZipPath) {
            $zipOk = Test-ZipFile -Path $ZipPath
            if (-not $zipOk.Valid) {
                Write-AIWarn "$Label archive is invalid ($($zipOk.Reason)). Removing and re-downloading (attempt $attempt/$MaxAttempts)."
                Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
            }
        }

        if (-not (Test-Path $ZipPath)) {
            $dlOk = Show-ProgressDownload -Url $Url -Destination $ZipPath -Label "Downloading $Label"
            if (-not $dlOk) {
                if ($attempt -ge $MaxAttempts) { return $false }
                continue
            }
        }

        $zipOk2 = Test-ZipFile -Path $ZipPath
        if (-not $zipOk2.Valid) {
            Write-AIWarn "$Label download looks corrupt ($($zipOk2.Reason)). Removing and retrying (attempt $attempt/$MaxAttempts)."
            Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
            if ($attempt -ge $MaxAttempts) { return $false }
            continue
        }

        $extractOk = Expand-ZipSafe -ZipPath $ZipPath -DestinationPath $DestinationPath -Label "Extracting $Label"
        if ($extractOk) {
            return $true
        }

        # Extraction failed (e.g., Central Directory corrupt). Remove zip and retry.
        Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
    }

    return $false
}

function Write-DownloadTroubleshooting {
    param(
        [string]$Label,
        [string]$Url,
        [string]$ZipPath
    )

    Write-Host "";
    Write-AIError "$Label could not be downloaded/extracted reliably."
    Write-AI "Common causes: proxy/antivirus modifying downloads, GitHub rate limits, or a partial transfer."
    Write-AI "You can manually download the file and place it here: $ZipPath"
    Write-AI "URL: $Url"
}

function Write-SuccessCard {
    param(
        [string]$WebUIPort = "3000",
        [string]$DashboardPort = "3001"
    )
    # Detect local IP for network access (DHCP, static, or manual -- exclude loopback + APIPA)
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -notlike "*Loopback*" -and
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -in @("Dhcp", "Manual")
        } | Select-Object -First 1).IPAddress
    if (-not $localIP) { $localIP = "your-ip" }

    Write-Host ""
    Write-Host ("  " + ("=" * 60)) -ForegroundColor Green
    Write-Host ""
    Write-Host "       THE GATEWAY IS OPEN" -ForegroundColor White
    Write-Host ""
    Write-Host "       Chat UI:    " -ForegroundColor DarkGray -NoNewline
    Write-Host "http://localhost:$WebUIPort" -ForegroundColor White
    Write-Host "       Dashboard:  " -ForegroundColor DarkGray -NoNewline
    Write-Host "http://localhost:$DashboardPort" -ForegroundColor White
    Write-Host "       Network:    " -ForegroundColor DarkGray -NoNewline
    Write-Host "http://${localIP}:$WebUIPort" -ForegroundColor White
    Write-Host ""
    Write-Host "       Manage:     " -ForegroundColor DarkGray -NoNewline
    Write-Host ".\dream.ps1 status" -ForegroundColor Cyan
    Write-Host "       Logs:       " -ForegroundColor DarkGray -NoNewline
    Write-Host ".\dream.ps1 logs llama-server" -ForegroundColor Cyan
    Write-Host "       Stop:       " -ForegroundColor DarkGray -NoNewline
    Write-Host ".\dream.ps1 stop" -ForegroundColor Cyan
    Write-Host ""
    $elapsed = ((Get-Date) - $script:INSTALL_START).ToString("mm\:ss")
    Write-Host "       Install completed in $elapsed" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("  " + ("=" * 60)) -ForegroundColor Green
    Write-Host ""
}
