param([switch]$IncludeSource)
$ErrorActionPreference = 'Stop'
$qaRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $qaRoot
$qaEvidence = Join-Path $qaRoot 'docs/qa/sprint6/evidence'
$qaHandoff = Join-Path $qaRoot 'build/sprint6-handoff'
New-Item -ItemType Directory -Force -Path $qaEvidence, $qaHandoff | Out-Null
$qaApk = Join-Path $qaRoot 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path -LiteralPath $qaApk)) { throw 'Build the final APK first.' }

# Print paths/counts only, never a potential matched credential.
$qaPattern = 'sk-(?:proj-)?[A-Za-z0-9_-]{20,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----'
$qaFiles = @(git ls-files --cached --others --exclude-standard | Where-Object {
    $_ -match '\.(dart|js|mjs|json|toml|md|yaml|yml|kt|properties|ps1)$' -and
    (Test-Path -LiteralPath $_)
})
$qaSourceMatches = @($qaFiles | Where-Object {
    [regex]::IsMatch([IO.File]::ReadAllText((Join-Path $qaRoot $_)), $qaPattern)
})
Add-Type -AssemblyName System.IO.Compression.FileSystem
$qaArchive = [IO.Compression.ZipFile]::OpenRead($qaApk)
$qaApkMatches = @()
try {
    foreach ($qaEntry in $qaArchive.Entries) {
        if ($qaEntry.Length -eq 0) { continue }
        $qaReader = [IO.StreamReader]::new($qaEntry.Open(), [Text.Encoding]::ASCII)
        try {
            if ([regex]::IsMatch($qaReader.ReadToEnd(), $qaPattern)) { $qaApkMatches += $qaEntry.FullName }
        } finally { $qaReader.Dispose() }
    }
} finally { $qaArchive.Dispose() }
$qaHash = (Get-FileHash -LiteralPath $qaApk -Algorithm SHA256).Hash
$qaScan = [ordered]@{
    sourceFilesScanned = $qaFiles.Count; sourceCandidatePaths = $qaSourceMatches
    apkCandidateEntries = $qaApkMatches; apkSHA256 = $qaHash
    note = 'Pattern scan only. Firebase public client identifiers are not provider secrets. No credentials printed.'
}
$qaScan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $qaEvidence 'credential-scan.json') -Encoding utf8
if ($qaSourceMatches.Count -or $qaApkMatches.Count) { throw 'Potential credential detected. See candidate paths, do not publish.' }

foreach ($qaName in @('flutter-regression.txt', 'flutter-analyze.txt', 'firebase-regression.txt', 'worker-tests.txt', 'worker-runtime.txt', 'worker-bundle.txt', 'apk-build.txt', 'chat-error.png', 'chat-success.png', 'chat-mobile-long.png')) {
    $qaFrom = Join-Path $qaRoot "build/sprint6-qa/$qaName"
    $qaTo = Join-Path $qaEvidence $qaName
    if ($qaName.EndsWith('.txt')) {
        # Preserve log content; normalize terminal-only trailing spaces for Git.
        $qaLog = [regex]::Replace([IO.File]::ReadAllText($qaFrom), '[ \t]+(?=\r?$)', '', [Text.RegularExpressions.RegexOptions]::Multiline)
        [IO.File]::WriteAllText($qaTo, $qaLog, [Text.UTF8Encoding]::new($false))
    } else { Copy-Item -LiteralPath $qaFrom -Destination $qaTo -Force }
}
foreach ($qaName in @('deployment-smoke.json', 'android-install.txt', 'android-launch.txt', 'android-startup.json', 'android-login.png')) {
    $qaFrom = Join-Path $qaRoot "build/sprint6-qa/$qaName"
    if (Test-Path -LiteralPath $qaFrom) {
        Copy-Item -LiteralPath $qaFrom -Destination (Join-Path $qaEvidence $qaName) -Force
    }
}
Copy-Item -LiteralPath $qaApk -Destination (Join-Path $qaHandoff 'HealWay-Sprint6.apk') -Force
$qaReport = Join-Path $qaRoot 'docs/qa/sprint6/report.md'
$qaContent = [IO.File]::ReadAllText($qaReport)
$qaContent = [regex]::Replace($qaContent, 'APK SHA-256: `[A-F0-9]{64}`', ('APK SHA-256: `' + $qaHash + '`'))
[IO.File]::WriteAllText($qaReport, $qaContent, [Text.UTF8Encoding]::new($false))

if ($IncludeSource) {
    $qaSourceZip = Join-Path $qaHandoff 'HealWay-Sprint6-source.zip'
    git archive --format=zip "--output=$qaSourceZip" HEAD
    if ($LASTEXITCODE -ne 0) { throw 'git archive failed' }
    $qaCommit = git rev-parse HEAD
    $qaManifest = [ordered]@{ commit = $qaCommit; sourceBranch = 'NgocVan'; quocVietReadOnlyRef = (git rev-parse origin/QuocViet)
        apkSHA256 = $qaHash; sourceSHA256 = (Get-FileHash -LiteralPath $qaSourceZip -Algorithm SHA256).Hash }
    $qaManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $qaHandoff 'manifest.json') -Encoding utf8
}
Write-Output "Packaged APK/evidence. APK SHA256: $qaHash"
