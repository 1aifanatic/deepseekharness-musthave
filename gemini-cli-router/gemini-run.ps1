param(
    [Parameter(Position = 0)]
    [string]$Prompt,

    [Parameter()]
    [string]$Model = "gemini-2.0-flash",

    [Parameter()]
    [string]$SystemInstruction,

    [Parameter()]
    [string]$ApiKey = $env:GEMINI_API_KEY
)

# If prompt not passed in args, read from stdin
if (-not $Prompt) {
    $inputLines = [Console]::In.ReadToEnd()
    if ($inputLines) {
        $Prompt = $inputLines.Trim()
    }
}

if (-not $Prompt) {
    Write-Error "No prompt provided."
    exit 1
}

# Check API key
if (-not $ApiKey) {
    # Check ~/.config/gemini-key or common locations
    $keyFile = "$env:USERPROFILE\.config\gemini-key.txt"
    if (Test-Path $keyFile) {
        $ApiKey = (Get-Content $keyFile -Raw).Trim()
    }
}

if (-not $ApiKey) {
    Write-Error "GEMINI_API_KEY environment variable is missing. Set `$env:GEMINI_API_KEY = 'AIza...' or place key in ~/.config/gemini-key.txt"
    exit 1
}

$endpoint = "https://generativelanguage.googleapis.com/v1beta/models/${Model}:generateContent?key=${ApiKey}"

$contents = @(
    @{
        role = "user"
        parts = @(
            @{ text = $Prompt }
        )
    }
)

$bodyObj = @{
    contents = $contents
}

if ($SystemInstruction) {
    $bodyObj["systemInstruction"] = @{
        parts = @(
            @{ text = $SystemInstruction }
        )
    }
}

$bodyJson = $bodyObj | ConvertTo-Json -Depth 6

try {
    $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 60
    if ($response.candidates -and $response.candidates[0].content.parts) {
        $outText = $response.candidates[0].content.parts[0].text
        Write-Output $outText
    } else {
        Write-Output ($response | ConvertTo-Json -Depth 5)
    }
} catch {
    Write-Error "Gemini API Request failed: $_"
    exit 1
}
