# Purpose: Use Device Code Flow to authenticate with Microsoft Graph API and retrieve user information.
# Device Code Flow is ideal for devices with limited input capabilities or command-line applications.

# The login process involves the user visiting a URL and entering a code to authenticate. All multifactor
# authentication methods supported by Azure AD are available during this process.

# Result: On success, saves access and refresh tokens to token.json and makes a test call to display user info.

# Use this script to authenticate with Microsoft Graph API and retrieve user information.
# It's useful to test that your Microsoft Graph API setup is working correctly. It also generates tokens for use in other scripts.

# The script will guide you through the authentication process and save the access and refresh tokens to a file.
# It requires a configuration file named config.json with the following structure: 
# {
#   "tenant_id": "your-tenant-id",
#   "client_id": "your-client-id",
#   "redirect_uri": "your-redirect-uri",    
#   "resource": "https://graph.microsoft.com"
# } 

# Usage:
# 1. Create a config.json file with the details of your app and tenant.
# 2. Run this script in PowerShell, specifying the path to your config.json file if it's not in the same directory.
# 3. Follow the prompts to authenticate and retrieve your user information.
#
# On Success, access and refresh tokens are saved to token.json.
# You can then use these tokens for subsequent API calls in your SAS programs or other scripts.

param(
    [string]$ConfigPath = "./config.json"
)

if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "Configuration file '$ConfigPath' not found. Verify the path to your config.json file and specify with -ConfigPath."
    exit 1
}

# get full path of config file
$ConfigPath = (Resolve-Path -Path $ConfigPath).Path

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$tenantId = $config.tenant_id
$clientId = $config.client_id

# -------------------------------
# Device Code Flow implementation
# Change Scopes as needed, most SAS use cases use 
# Files.ReadWrite.All and Sites.ReadWrite.All for OneDrive/SharePoint access
# Note that offline_access is required to get a refresh token!
# -------------------------------
$Scopes    = "User.Read Files.ReadWrite.All Sites.ReadWrite.All openid profile offline_access"

# Request device & user code
$deviceCodeEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode"
$headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
$body    = @{
    client_id = $clientId
    scope     = $Scopes  # space-separated delegated scopes for Graph API
}

$dc = Invoke-RestMethod -Method POST -Uri $deviceCodeEndpoint -Headers $headers -Body $body

Write-Host $dc.message
Write-Host "Code will expire in $([math]::Round($dc.expires_in / 60, 2)) minutes."
Start-Process $dc.verification_uri

# Poll /token for authorization completion
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
$tokenBody = @{
    grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
    client_id   = $clientId
    device_code = $dc.device_code
}

$token = $null
do {
    Start-Sleep -Seconds $dc.interval
    try {
        $token = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Headers $headers -Body $tokenBody
    }
    catch {
        # Will result in HTTP 400 until user completes authentication
        # Common transient response before user completes auth: authorization_pending        
        $err = $_.ErrorDetails | ConvertFrom-Json
        Write-Host "Waiting for user to complete sign-in... ($($err.error))"
    }
} until ($token -and $token.access_token)

if ($token -and $token.access_token) {
    Write-Host "Authentication complete. Access token acquired."
    # save the token.json to an external file in the same directory as config.json
    $tokenFilePath = Join-Path -Path (Split-Path -Parent $ConfigPath) -ChildPath "token.json"
    $token | ConvertTo-Json -Depth 5 | Set-Content -Path $tokenFilePath -Force  
    Write-Host "Access and refresh tokens saved to $tokenFilePath"
} else {
    Write-Error "Failed to acquire access token."
    exit 1
}

# Call Microsoft Graph with the bearer token
$graphHeaders = @{ "Authorization" = "Bearer $($token.access_token)" }

# Example: GET /me
$me = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -Headers $graphHeaders
$me | Format-List

