# Define the variables
$appName = "yourAppName"
$resourceGroup = "yourResourceGroup"
$subscriptionId = "yourSubscriptionId"
$zipFilePath = "path\to\your\zipfile.zip"
$apiUrl = "https://$appName.scm.azurewebsites.net/api/zipdeploy"

# Get the Azure context
Connect-AzAccount

# Set the subscription
Set-AzContext -SubscriptionId $subscriptionId

# Read the ZIP file as bytes
$zipFileBytes = [System.IO.File]::ReadAllBytes($zipFilePath)

# Convert the ZIP file bytes to a base64 string
$base64ZipFile = [Convert]::ToBase64String($zipFileBytes)

# Create the headers
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $(Get-AzAccessToken -ResourceUrl 'https://management.azure.com')"
}
# Create the body
$body = @{
    "ZipFile" = $base64ZipFile
} | ConvertTo-Json

# Send the POST request
Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body
