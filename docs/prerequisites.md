# Azure Virtual Desktop Solution

[**Home**](../README.md) | [**Features**](./features.md) | [**Design**](./design.md) | [**Prerequisites**](./prerequisites.md) | [**Troubleshooting**](./troubleshooting.md)

## Prerequisites

To successfully deploy this solution, you will need to ensure the following prerequisites have been completed:

### Required

- **Licenses:** ensure you have the [required licensing for AVD](https://learn.microsoft.com/en-us/azure/virtual-desktop/overview#requirements).
- **Artifacts:** the deployment of this solution depends on many artifacts that must be hosted in Azure Blobs. This solution includes a helper script to automatically download these files and and upload them to a storage account. See [Upload-ArtifactsToStorage.ps1](../artifactsStorageAccount/Upload-ArtifactsToStorage.ps1).
  - [AVD Agent](https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv)
  - [AVD Agent Boot Loader](https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH)
  - [Azure PowerShell AZ Module](https://github.com/Azure/azure-powershell/releases/latest). Download the 64-bit MSI located under Assets.
  - [PowerShell Scripts](../.common/artifacts)
  
- **Azure Permissions:** ensure the principal deploying the solution has "Owner" and "Key Vault Administrator" roles assigned on the target Azure subscription. This solution contains many role assignments at different scopes and deploys a key vault with keys and secrets to enhance security.
- **Security Group:** create a security group for your AVD users.
  - AD DS: create the group in ADUC and ensure the group has synchronized to Azure AD.
  - Azure AD: create the group.
  - Azure AD DS: create the group in Azure AD and ensure the group has synchronized to Azure AD DS.
- **Disk Encryption:** the "encryption at host" feature is deployed on the virtual machines to meet Zero Trust compliance. This feature is not enabled in your Azure subscription by default and must be manually enabled. Use the following steps to enable the feature: [Enable Encryption at Host](https://learn.microsoft.com/azure/virtual-machines/disks-enable-host-based-encryption-portal).
- **Enable AVD Private Link** this feature is not enabled on subscriptions by default. Use the following link to enable AVD Private Link on your subscription: [Enable the Feature](https://learn.microsoft.com/azure/virtual-desktop/private-link-setup?tabs=portal%2Cportal-2#enable-the-feature)

### Optional

- **Domain Services:** if you plan to domain or hybrid join the session hosts, ensure Active Directory Domain Services or Entra Domain Services is available in your enviroment and that you are synchronizing the required objects. AD Sites & Services should be configured for the address space of your Azure virtual network if you are extending your on premises Active Directory infrastruture into the cloud.
- **DNS:** There are several DNS requirements:
  - If you plan to domain or hybrid join the sessions hosts, you must configure your subnets to resolve the Domain SRV records for Domain location services to function. This is normally accomplished by configuring custom DNS settings on your AVD session host Virtual Networks to point to the Domain Controllers or using a DNS resolver that can resolve the internal domain records.
  - In order to use private links and disable public access to storage accounts, key vaults, and automation accounts (in accordance with Zero Trust Guidance), you must ensure that the private DNS zones are also resolvable from the session host Virtual Networks.
- **Domain Permissions**
  - for Active Directory Domain Services, create a principal to domain join the session hosts and Azure Files, using the following steps:
    1. Open **Active Directory Users and Computers**.
    2. Navigate to your service accounts Organizational Unit (OU).
    3. Right-click on the OU and select **New > User**.
    4. Type the appropriate values into the dialog box. Recommend that you set a strong password and set the *Password never expires* option. Complete the creation of the *service* account.
    5. In the **Active Directory Users and Computers** mmc, select **View > Advanced Features** from the menu bar.
    6. Create an OU for the AVD computers if not already present.
    7. Right-click on the AVD computer OU and select **Properties**.
    8. Select the **Security** tab.
    9. Click the **Advanced** button.
    10. In the **Advanced Security Settings for *OU Name*** window, click the **Add** button.
    11. Select a principal by clicking on the **Select a principal** link. Search for the newly created *service* account, click on **Check Names**, and then click **OK**.
    12. In the **Permission Entry for *OU Name*** window, ensure that the "Applies to:" drop down is set to "This object and all descendant objects" and then under Permissions, select only "Create Computer Objects" and "Delete Computer Objects". Select **OK** to save the entry.
    13. Back in the **Advanced Security Settings for *OU Name*** window, click the **Add** button.
    14. Select a principal by clicking on the **Select a principal** link. Search for the newly created *service* account, click on **Check Names**, and then click **OK**.
    15. In the **Permission Entry for *OU Name*** window, ensure that the "Applies to:" drop down is set to "Descendant Computer objects" and then under Permissions, select only "Read all properties", "Write all properties", "Read permissions", "Modify permissions", "Change password", "Reset password", "Validated write to DNS host name", and "Validated write to service principal name". Select **OK** to save the entry.
    16. Select **OK** until you are returned to the **Active Directory Users and Computers** window.
  - for Entra Domain Services, ensure the principal is a member of the "AAD DC Administrators" group in Azure AD.
- **FSLogix with Azure NetApp Files:** the following steps must be completed if you plan to use this service.
  - [Register the resource provider](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-register)
  - [Enable the shared AD feature](https://learn.microsoft.com/azure/azure-netapp-files/create-active-directory-connections#shared_ad) - this feature is required if you plan to deploy more than one domain joined NetApp account in the same Azure subscription and region.
- **Marketplace Image:** If you plan to deploy this solution using PowerShell or AzureCLI and use a marketplace image for the virtual machines, use the code below to find the appropriate image:

```powershell
# Determine the Publisher; input the location for your AVD deployment
$Location = ''
(Get-AzVMImagePublisher -Location $Location).PublisherName

# Determine the Offer; common publisher is 'MicrosoftWindowsDesktop' for Win 10/11
$Publisher = ''
(Get-AzVMImageOffer -Location $Location -PublisherName $Publisher).Offer

# Determine the SKU; common offers are 'Windows-10' for Win 10 and 'office-365' for the Win10/11 multi-session with M365 apps
$Offer = ''
(Get-AzVMImageSku -Location $Location -PublisherName $Publisher -Offer $Offer).Skus

# Determine the Image Version; common offers are '21h1-evd-o365pp' and 'win11-21h2-avd-m365'
$Sku = ''
Get-AzVMImage -Location $Location -PublisherName $Publisher -Offer $Offer -Skus $Sku | Select-Object * | Format-List

# Common version is 'latest'
```
