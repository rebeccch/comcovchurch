# regen-events.ps1 — reads events.csv and rebuilds upcoming-event cards and headline banners
# Usage:  powershell -ExecutionPolicy Bypass -File .\regen-events.ps1

param([int]$MaxUpcoming = 4)

$root = $PSScriptRoot
$csvPath = Join-Path $root 'events.csv'
$indexPath = Join-Path $root 'index.html'
$eventsPath = Join-Path $root 'events.html'

$today = [int](Get-Date -Format 'yyyyMMdd')
Write-Host "regen-events: today=$today, max=$MaxUpcoming"

$rows = Import-Csv $csvPath
$upcoming = $rows |
    Where-Object { [int]$_.sort_date -ge $today } |
    Sort-Object { [int]$_.sort_date } |
    Select-Object -First $MaxUpcoming

Write-Host "  showing $($upcoming.Count) event(s)"

$palette = @{
    'sage' = @{ bg='#d4edda'; text='#2a6e40'; featured=$false }
    'teal' = @{ bg='#cef0ee'; text='#1a6060'; featured=$false }
    'gold' = @{ bg='#fef9c3'; text='#7a6010'; featured=$false }
    'blue' = @{ bg='#2e6da4'; text='#fff';    featured=$true  }
}

function StatusLabel($s) {
    if ($s -eq 'closed')    { return 'Registration Closed' }
    if ($s -eq 'postponed') { return 'Postponed' }
    return $s
}

function CardHtml($row) {
    $p = $palette[$row.color]
    if (-not $p) { $p = $palette['gold'] }
    $cardClass = 'event-card'
    if ($p.featured) { $cardClass = 'event-card featured' }
    $statusBlock = ''
    if ($row.status -and $row.status.Trim() -ne '') {
        $label = StatusLabel $row.status.Trim()
        $statusBlock = "`n        <div class=" + '"event-special-tag"' + " style=" + '"background:#888; margin-top:10px; margin-bottom:0;"' + ">$label</div>"
    }
    $out = @()
    $out += "    <div class=" + '"' + $cardClass + '"' + ">"
    $out += "      <div class=" + '"event-color-bar"' + " style=" + '"background:' + $p.bg + ';"><span style="color:' + $p.text + ';">' + $row.date_display + "</span></div>"
    $out += "      <div class=" + '"event-body"' + ">"
    $out += "        <div class=" + '"event-name"' + ">" + $row.name + "</div>"
    $out += "        <div class=" + '"event-detail"' + ">" + $row.detail + "</div>" + $statusBlock
    $out += "      </div>"
    $out += "    </div>"
    return ($out -join "`n")
}

function HeadlineHtml($row) {
    $images = @()
    if ($row.images) {
        $images = @($row.images.Split('|') | Where-Object { $_.Trim() -ne '' })
    }
    $posterHtml = ''
    if ($images.Count -eq 1) {
        $posterHtml = "`n  <a class=" + '"headline-poster"' + " href=" + '"' + $images[0] + '"' + " target=" + '"_blank"' + " rel=" + '"noopener"' + ">`n    <img src=" + '"' + $images[0] + '"' + " alt=" + '"' + $row.name + '"' + ">`n  </a>"
    } elseif ($images.Count -gt 1) {
        $inner = @()
        foreach ($img in $images) {
            $inner += "    <a href=" + '"' + $img + '"' + " target=" + '"_blank"' + " rel=" + '"noopener"' + ">`n      <img src=" + '"' + $img + '"' + " alt=" + '"' + $row.name + '"' + ">`n    </a>"
        }
        $posterHtml = "`n  <div class=" + '"headline-posters"' + ">`n" + ($inner -join "`n") + "`n  </div>"
    }
    $out = @()
    $out += "<section class=" + '"headline"' + ">"
    $out += "  <div class=" + '"headline-text"' + ">"
    $out += "    <div class=" + '"section-eyebrow"' + ">Save the date</div>"
    $out += "    <h2 class=" + '"section-title"' + ">" + $row.name + "</h2>"
    $out += "    <p class=" + '"section-body"' + ">" + $row.banner_text + "</p>"
    $out += "  </div>" + $posterHtml
    $out += "</section>"
    return ($out -join "`n")
}

$cardsList = @()
$headlinesList = @()
foreach ($e in $upcoming) {
    $cardsList += CardHtml $e
    if ($e.featured -eq 'yes') {
        $headlinesList += HeadlineHtml $e
    }
}
$cards = $cardsList -join "`n"
$headlines = $headlinesList -join "`n`n"

Write-Host "  generated $($cardsList.Count) card(s), $($headlinesList.Count) banner(s)"

$upcomingPattern  = '(?s)<!-- EVENTS:UPCOMING:START -->.*?<!-- EVENTS:UPCOMING:END -->'
$headlinesPattern = '(?s)<!-- EVENTS:HEADLINES:START -->.*?<!-- EVENTS:HEADLINES:END -->'
$upcomingReplacement  = "<!-- EVENTS:UPCOMING:START -->`n$cards`n<!-- EVENTS:UPCOMING:END -->"
$headlinesReplacement = "<!-- EVENTS:HEADLINES:START -->`n$headlines`n<!-- EVENTS:HEADLINES:END -->"

foreach ($file in @($indexPath, $eventsPath)) {
    $c = [IO.File]::ReadAllText($file, [System.Text.UTF8Encoding]::new($false))
    $c = [regex]::Replace($c, $upcomingPattern,  $upcomingReplacement)
    $c = [regex]::Replace($c, $headlinesPattern, $headlinesReplacement)
    # Normalize to CRLF for Windows
    $c = $c -replace "`r`n", "`n" -replace "`n", "`r`n"
    [IO.File]::WriteAllText($file, $c, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  wrote: $(Split-Path $file -Leaf)"
}

# Update Last Updated date on every HTML page
$todayDisplay = (Get-Date -Format 'MMMM d, yyyy')
$updatedPattern = '(?<=<span class="footer-updated">Last Updated: )[^<]+(?=</span>)'
$updated = 0
foreach ($file in (Get-ChildItem $root -Filter '*.html')) {
    $c = [IO.File]::ReadAllText($file.FullName, [System.Text.UTF8Encoding]::new($false))
    $new = [regex]::Replace($c, $updatedPattern, $todayDisplay)
    if ($new -ne $c) {
        [IO.File]::WriteAllText($file.FullName, $new, [System.Text.UTF8Encoding]::new($false))
        $updated++
    }
}
Write-Host "  Last Updated -> '$todayDisplay' on $updated page(s)"
Write-Host "Done."
