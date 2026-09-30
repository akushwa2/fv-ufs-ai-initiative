<#
.SYNOPSIS
  100%-reliable, size-independent HSD-ES comment retrieval.

.DESCRIPTION
  THE method. HSD-ES embeds an article's ENTIRE comment thread in a single
  'comments' field, retrievable from the main article web-service:

      GET /rest/article/{id}?fields=comments

  This endpoint is served by 'articlews' and accepts the caller's Kerberos
  ticket (integrated Windows auth) -- HSD-ES's preferred auth -- with NO token,
  NO AGS role, and it does NOT hit the 431 (oversized-SPNEGO) wall that the
  newer /api/comment surface does. Because the whole thread comes back as one
  field, ticket size is irrelevant: there is no pagination to get wrong and no
  comments can be silently dropped.

  Comments arrive delimited as:   ++++<commentId> <author>\n<html body>
  This script splits, strips HTML, and writes clean markdown.

  Why not the alternatives (documented so we never chase them again):
    * /rest/article/{id}/comments|/comment   -> 404 (articlews has no such sub-resource)
    * /rest/articlecomment/{id}              -> 401 Basic realm="karaf" (needs token + AGS role)
    * /api/comment/{id} (hsdes / hsdes-api)  -> Kerberos 431 (PAC too large); Bearer 401
    * Web UI Comment tab                     -> intermittently disabled (comment micro-fe 503-flaky); not automatable
    * axon.intel.com                         -> generic query platform, no comment store

.PARAMETER Id
  HSD article/bug/sighting ID.

.PARAMETER OutFile
  Where to save the decoded thread (markdown). Defaults next to this script.

.EXAMPLE
  .\hsd-comments.ps1 -Id 15019125953
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Id,
  [string]$OutFile
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$auth = @{ UseDefaultCredentials = $true }   # Kerberos / integrated auth, no secret

function Strip-Html([string]$h) {
  if (-not $h) { return '' }
  $t = $h -replace '(?is)<style.*?</style>', '' -replace '(?is)<script.*?</script>', ''
  $t = $t -replace '(?i)</p>|<br\s*/?>|</div>|</li>', "`n" -replace '(?i)<li[^>]*>', '- '
  $t = $t -replace '<[^>]+>', ''
  $t = [System.Net.WebUtility]::HtmlDecode($t)
  ($t -replace '[ \t]+', ' ' -replace '(\r?\n\s*){3,}', "`n`n").Trim()
}

# --- fetch the whole thread in one call (size-independent) ---
$raw = $null
foreach ($h in @('https://hsdes.intel.com','https://hsdes-api.intel.com')) {
  $u = "$h/rest/article/$Id`?fields=comments"
  try {
    $resp = Invoke-RestMethod -Uri $u @auth -Headers @{ Accept = 'application/json' } -Method GET
    $raw = $resp.data[0].comments
    if ($null -ne $raw) { Write-Host "[OK] $u  (comments field = $($raw.Length) chars)" -ForegroundColor Green; break }
    Write-Host "[200 but no comments field] $u" -ForegroundColor DarkGray
  } catch {
    Write-Host "[$($_.Exception.Response.StatusCode.value__)] $u" -ForegroundColor DarkGray
  }
}
if ($null -eq $raw) { Write-Warning "Could not retrieve comments field. Check Kerberos/access and re-run."; return }
if ($raw -eq '')   { Write-Host "Ticket $Id has no comments." -ForegroundColor Yellow; return }

# --- split on the ++++<id> <author> record delimiter (anchor on id+idsid, not line-start) ---
$blocks = [regex]::Split($raw, '\+\+\+\+(?=\d+\s+\S)') | Where-Object { $_ -match '\S' }
if (-not $OutFile) { $OutFile = Join-Path $PSScriptRoot "comments_$Id.md" }
"# HSD $Id - $($blocks.Count) comments (retrieved $(Get-Date -Format s), fields=comments)`n" | Set-Content -Path $OutFile -Encoding UTF8

$i = 0
foreach ($b in $blocks) {
  $i++
  $nl = $b.IndexOf("`n")
  if ($nl -lt 0) { $header = $b.Trim(); $body = '' } else { $header = $b.Substring(0, $nl).Trim(); $body = $b.Substring($nl + 1) }
  $cid = ($header -split '\s+')[0]
  $author = ($header -replace '^\S+\s*', '').Trim()
  "## [$i] $author  (comment $cid)`n`n$(Strip-Html $body)`n" | Add-Content -Path $OutFile -Encoding UTF8
}
Write-Host "Saved $($blocks.Count) comments -> $OutFile" -ForegroundColor Green
