# AppServiceManagedCertificates
Sample PowerShell script that finds Azure App Services using the App Service Managed Certificate (ASMC) feature that will not be able to renew their certificate because some configuration feature on the site prevents public network access. Configurations that prevent certificate renewal include:

1. Public network access is disabled
1. Client certificate authentication is enabled
1. A Deny All public IP address restriction is in place

## Prerequisites
1. Install the latest Azure CLI [https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
1. Install the Resource Graph extension for the Azure CLI [https://learn.microsoft.com/en-us/azure/governance/resource-graph/first-query-azurecli#install-the-extension](https://learn.microsoft.com/en-us/azure/governance/resource-graph/first-query-azurecli#install-the-extension)

1. To make sure you identify all impacted resources, the account that executes this script must have at least Reader access to all of the subscriptions that will be scanned.

## WebAppsASMC.ps1

### Parameters
- **subscriptionId** - Optional. The unique identifier of an Azure subscription. If provided, only App Services from this subscription will be scanned. If not provided, App Services across all subscriptions that the current user has access to will be scanned.

### Output
- SiteSubscriptionId
- SiteResourceGroup
- AppService
- SiteId
- PublicNetworkAccess
- ClientCertEnabled
- WebsiteLoadCertificates
- IpRestrictionsDenyPublicAccess
- HostName
- Thumbprint
- CertSubscriptionId
- CertResourceGroup
- CertName
- CertId
- CertExpiration
- CanonicalName

