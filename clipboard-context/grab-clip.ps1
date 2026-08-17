param(
    [Parameter()]
    [switch]$CleanTerminal,

    [Parameter()]
    [switch]$SaveImage,

    [Parameter()]
    [string]$ImagePath = "$env:TEMP\agent-clipboard-image.png"
)

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

# Check if clipboard contains an image
if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    if ($img) {
        $img.Save($ImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "[CLIPBOARD_IMAGE_SAVED: $ImagePath]"
        exit 0
    }
}

# Grab clipboard text
$text = Get-Clipboard -Raw -ErrorAction SilentlyContinue

if (-not $text) {
    Write-Output "[CLIPBOARD_EMPTY]"
    exit 0
}

# Strip ANSI color codes
$cleaned = $text -replace '\x1B\[[0-9;]*[a-zA-Z]', ''

# Optional terminal prompt cleanup
if ($CleanTerminal) {
    $cleaned = $cleaned -replace '(?m)^[PS\s>#$].*?>\s*', ''
}

Write-Output $cleaned
