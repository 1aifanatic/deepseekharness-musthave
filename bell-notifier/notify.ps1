param(
    [Parameter(Position = 0)]
    [string]$Message = "Agent task completed!",

    [Parameter(Position = 1)]
    [string]$Title = "AI Agent Notification",

    [Parameter()]
    [string]$Topic = $env:AGENT_NOTIFY_TOPIC,

    [Parameter()]
    [string]$DiscordWebhook = $env:AGENT_DISCORD_WEBHOOK,

    [Parameter()]
    [string]$TelegramToken = $env:AGENT_TELEGRAM_TOKEN,

    [Parameter()]
    [string]$TelegramChatId = $env:AGENT_TELEGRAM_CHAT_ID,

    [Parameter()]
    [string]$Tags = "robot,white_check_mark",

    [Parameter()]
    [switch]$SoundOnly
)

# Load optional config file if present
$configFile = "$env:USERPROFILE\.config\agent-notify.json"
if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        if (-not $Topic -and $config.topic) { $Topic = $config.topic }
        if (-not $DiscordWebhook -and $config.discordWebhook) { $DiscordWebhook = $config.discordWebhook }
        if (-not $TelegramToken -and $config.telegramToken) { $TelegramToken = $config.telegramToken }
        if (-not $TelegramChatId -and $config.telegramChatId) { $TelegramChatId = $config.telegramChatId }
    } catch {}
}

# 1. System sound / beep
try {
    [System.Console]::Beep(880, 200)
    Start-Sleep -Milliseconds 50
    [System.Console]::Beep(1175, 300)
} catch {}

if ($SoundOnly) {
    Write-Output "Sound played."
    exit 0
}

# 2. ntfy.sh free push notification (if topic configured or fallback provided)
if ($Topic) {
    try {
        $headers = @{
            "Title" = $Title
            "Tags"  = $Tags
        }
        $url = "https://ntfy.sh/$Topic"
        $null = Invoke-RestMethod -Uri $url -Method Post -Body $Message -Headers $headers -TimeoutSec 10
        Write-Output "Push sent to ntfy.sh/$Topic"
    } catch {
        Write-Warning "Failed to send ntfy notification: $_"
    }
}

# 3. Discord Webhook (optional)
if ($DiscordWebhook) {
    try {
        $payload = @{
            username = "AI Agent"
            embeds = @(@{
                title = $Title
                description = $Message
                color = 3066993
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
            })
        } | ConvertTo-Json -Depth 4

        $null = Invoke-RestMethod -Uri $DiscordWebhook -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10
        Write-Output "Sent to Discord webhook."
    } catch {
        Write-Warning "Failed to send Discord webhook: $_"
    }
}

# 4. Telegram (optional)
if ($TelegramToken -and $TelegramChatId) {
    try {
        $tgUrl = "https://api.telegram.org/bot$TelegramToken/sendMessage"
        $tgPayload = @{
            chat_id = $TelegramChatId
            text = "<b>$Title</b>`n$Message"
            parse_mode = "HTML"
        } | ConvertTo-Json
        $null = Invoke-RestMethod -Uri $tgUrl -Method Post -Body $tgPayload -ContentType "application/json" -TimeoutSec 10
        Write-Output "Sent to Telegram."
    } catch {
        Write-Warning "Failed to send Telegram message: $_"
    }
}

if (-not $Topic -and -not $DiscordWebhook -and -not ($TelegramToken -and $TelegramChatId)) {
    Write-Output "Local chime sounded. Tip: Set `$env:AGENT_NOTIFY_TOPIC='your-private-channel' or create ~/.config/agent-notify.json for instant mobile push alerts via the free ntfy app!"
}
