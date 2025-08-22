#===============================================================================
# Copyright © Microsoft Corporation.  All rights reserved.
# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY
# OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE.
#===============================================================================
param(
    [Parameter(Mandatory)]$subscriptionId
)
$impactedWebApps = @()

az login

# If a subscription ID was provided, limit the results of the query to resources included in the supplied subscription only
if ($subscriptionId) {
    Write-Host "Subscription ID entered" $subscriptionId "searching for impacted resources across this subscription"
    $graphQuery = "resources | where type == 'microsoft.web/sites' and subscriptionId == '$subscriptionId'"
}
else {
    Write-Host "No subscription ID entered. Searching for impacted resources across all subscriptions"
    $graphQuery = "resources | where type == 'microsoft.web/sites'"
}

# Find all App Services with an App Service Managed Certificate (ASMC)
$graphQuery += " | extend publicNetworkAccess = tolower(tostring(properties.publicNetworkAccess)), clientCertEnabled = tolower(tostring(properties.clientCertEnabled))"
$graphQuery += " | mv-expand hostNameSslState = properties.hostNameSslStates"
$graphQuery += " | extend hostName = tostring(hostNameSslState.name), thumbprint = tostring(hostNameSslState.thumbprint)" 
$graphQuery += " | where tolower(hostName) !endswith 'azurewebsites.net' and isnotempty(thumbprint)"
$graphQuery += " | project siteSubscriptionId = subscriptionId, siteName = name, siteId = id, siteResourceGroup = resourceGroup, thumbprint, publicNetworkAccess, clientCertEnabled"
$graphQuery += " | join kind=inner (" 
$graphQuery += "     resources" 
$graphQuery += "     | where type == 'microsoft.web/certificates'"
$graphQuery += "     | extend certThumbprint = tostring(properties.thumbprint), canonicalName = tostring(properties.canonicalName)" 
$graphQuery += "     | where isnotempty(canonicalName)" 
$graphQuery += "     | project certSubscriptionId = subscriptionId, certName = name, certId = id, certResourceGroup = tostring(properties.resourceGroup), certExpiration = properties.expirationDate, certThumbprint, canonicalName"
$graphQuery += '   ) on $left.thumbprint == $right.certThumbprint'
$graphQuery += " | project siteSubscriptionId, siteName, siteId, siteResourceGroup, publicNetworkAccess, clientCertEnabled, thumbprint, certSubscriptionId, certName, certId, certResourceGroup, certExpiration, canonicalName"

# Find App Services impacted by the DigiCert Certificate Issuance and Renewal changes
$skipToken = ""
Do {
    # Batches of 100 to avoid throttling
    if ($skipToken -eq "") {
        $webApps = az graph query -q $graphQuery --first 100 | ConvertFrom-Json
    }
    else {
        $webApps = az graph query -q $graphQuery --first 100 --skip-token $skipToken | ConvertFrom-Json
    }

    if ($webApps -and $webApps.count -gt 0) { 
        $skipToken = $webApps.skip_token

        $webApps.data | ForEach-Object {
    
            $appSettings = az webapp config appsettings list --name $_.siteName --resource-group $_.siteResourceGroup --subscription $_.siteSubscriptionId --output json | ConvertFrom-Json
            $ipRestrictions = az webapp config access-restriction show --name $_.siteName --resource-group $_.siteResourceGroup --subscription $_.siteSubscriptionId --output json | ConvertFrom-Json
    
            # Capture the website load certificates setting
            $websiteLoadCertificates = ""
            $appSettings | ForEach-Object {
                if ($_.name -eq "WEBSITE_LOAD_CERTIFICATES") {
                    $websiteLoadCertificates = $_.value
                }
            }
    
            # Is a Deny all IP address restriction in place?
            $ipRestrictionsDenyPublicAccess = $false
            $ipRestrictions.ipSecurityRestrictions | ForEach-Object {
                if ($_.action -eq "Deny" -and $_.ip_address -eq "Any" -and $_.priority -eq 2147483647) {
                    $ipRestrictionsDenyPublicAccess = $true
                }
            }

            # Impacted resources meet one of the following criteria:
            #     - Public network access disabled
            #     - Client Certificate Authentication enabled
            #     - A Deny All public IP restriction    
            if ($_.publicNetworkAccess -eq "disabled" -or $_.clientCertEnabled -ne "false" -or $ipRestrictionsDenyPublicAccess -eq $true) {
                $webApp = @()
                $webApp = [PSCustomObject]@{
                    SiteSubscriptionId = $_.siteSubscriptionId
                    SiteResourceGroup = $_.siteResourceGroup
                    AppService = $_.siteName
                    SiteId = $_.siteId
                    PublicNetworkAccess = $_.publicNetworkAccess
                    ClientCertEnabled = $_.clientCertEnabled
                    WebsiteLoadCertificates = $websiteLoadCertificates
                    IpRestrictionsDenyPublicAccess = $ipRestrictionsDenyPublicAccess
                    HostName = $_.hostName
                    Thumbprint = $_.thumbprint
                    CertSubscriptionId = $_.certSubscriptionId
                    CertResourceGroup = $_.certResourceGroup
                    CertName = $_.certName
                    CertId = $_.certId
                    CertExpiration = $_.certExpiration
                    CanonicalName = $_.canonicalName
                }
                $impactedWebApps += $webApp
            }
        }
    }
    else {
        $skipToken = ""
    }
} While ($skipToken -ne "")

# Display impacted App Services
$impactedWebApps | Out-GridView