
$vault = "C:\Users\carso\Downloads\ObsidianVaults\KeysOfNine\Idyll"
$destination = "C:\Users\carso\quartz\content"

# Only these folders can contain public notes.
$publicFolders = @(
    "00 Home",
    "10 Player Notes"
)

if (-not (Test-Path -LiteralPath $vault -PathType Container)) {
    throw "Obsidian vault not found: $vault"
}

# Find notes only within approved folders.
$approved = @(
    foreach ($folder in $publicFolders) {
        $source = Join-Path $vault $folder

        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            Write-Warning "Folder not found: $source"
            continue
        }

        Get-ChildItem -LiteralPath $source -Recurse -File -Filter "*.md" |
        Where-Object {
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        } |
        Where-Object {
    $content = [IO.File]::ReadAllText($_.FullName)

    $frontmatter = [regex]::Match(
        $content,
        '\A(?:\uFEFF)?---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if (-not $frontmatter.Success) {
        return $false
    }

    [regex]::IsMatch(
        $frontmatter.Groups[1].Value,
        '(?im)^[ \t]*publish:[ \t]*true[ \t]*(?:#.*)?$'
    )
}
    }
)

if ($approved.Count -eq 0) {
    throw "No public notes found. Nothing was changed."
}
$landingPage = Join-Path $vault "00 Home\Landing Page.md"

if (-not ($approved | Where-Object {
    $_.FullName -eq $landingPage
})) {
    throw "Public landing page not found. Nothing was changed."
}
# Clear previously published content.
$expectedDestination = "C:\Users\carso\quartz\content"

if (
    [IO.Path]::GetFullPath($destination).TrimEnd('\') -ine
    [IO.Path]::GetFullPath($expectedDestination).TrimEnd('\')
) {
    throw "Safety check failed: unexpected destination path."
}
if (Test-Path -LiteralPath $destination) {
    $destinationItem = Get-Item -LiteralPath $destination -Force

    if ($destinationItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Safety check failed: destination is a symbolic link or junction."
    }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Get-ChildItem -LiteralPath $destination -Force |
    Remove-Item -Recurse -Force

# Copy approved notes, preserving folder structure.
foreach ($file in $approved) {
    $relative = $file.FullName.Substring(
        $vault.TrimEnd('\').Length
    ).TrimStart('\')

    # Publish the Obsidian landing page as the Quartz homepage.
    if ($relative -eq "00 Home\Landing Page.md") {
        $relative = "index.md"
    }

    $target = Join-Path $destination $relative
    $targetFolder = Split-Path $target -Parent

    New-Item -ItemType Directory -Path $targetFolder -Force |
        Out-Null

    Copy-Item -LiteralPath $file.FullName -Destination $target
    Write-Host "Published: $relative"
}

Write-Host ""
Write-Host "Published $($approved.Count) public notes."
