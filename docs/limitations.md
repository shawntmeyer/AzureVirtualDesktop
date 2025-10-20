[**Home**](../README.md) | [**Design**](design.md) | [**Features**](features.md) | [**Quick Start**](quickStart.md) | [**Troubleshooting**](troubleshooting.md) | [**Parameters**](parameters.md) | [**Zero Trust Framework**](zeroTrustFramework.md)

# Solution Limitations

This document outlines the known limitations and considerations when deploying the Azure Virtual Desktop (AVD) solution in this repository.

## Identity Solution Limitations

### Entra Kerberos Identity Solution

When configuring **Entra Kerberos** as the identity solution, the following limitations apply:

#### MFA and Azure Files Enterprise Application Permissions

> [!IMPORTANT]
> The solution does **not** automatically configure Multi-Factor Authentication (MFA) or grant permissions to the Azure Files storage account enterprise application when using Entra Kerberos identity.

**Manual Configuration Required:**

- **Grant Admin Consent to the new service principal**: You must manually grant admin consent to the service principals representing the Azure storage account(s) for FSLogix. See [Grant admin consent to the new service principal](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable?tabs=azure-portal%2Cintune)
- **Disable MFA on the storage account**: You must exclude the Microsoft Entra App representing your storage account from your MFA conditional access policies. See [Disable multifactor authentication on the storage account](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable?tabs=azure-portal%2Cintune#disable-multifactor-authentication-on-the-storage-account)

**Impact:**

- Users may experience authentication failures to FSLogix file shares if Azure Files enterprise application permissions are not properly configured
- Security policies requiring MFA will not be automatically enforced and must be configured separately

#### Active Directory Group Requirements

When using **Entra Kerberos** identity solution, security groups must meet specific requirements:

**Group Creation Requirements:**

- Groups must be created in **Active Directory** (on-premises)
- Groups must be synchronized to **Entra ID** through Azure AD Connect or equivalent synchronization method
- Groups cannot be cloud-only Entra ID groups

### Active Directory Domain Services Identity Solution

When configuring **Active Directory Domain Services** as the identity solution, similar group requirements apply:

#### Active Directory Group Requirements

**Group Creation and Synchronization:**

- Groups used for application group assignments must be **Active Directory groups**
- Groups used for FSLogix share permissions must be **Active Directory groups**  
- Groups must be synchronized to **Entra ID**

**Group Resolution Behavior:**

- Groups must be resolvable by **group name** to an actual on-premises Active Directory group
- Group resolution occurs from the domain context of the virtual machines

#### Multi-Domain Forest Considerations

> [!IMPORTANT]
> In multi-domain forest scenarios, group name resolution follows specific precedence rules that can impact permissions assignment.

**Group Name Resolution Logic:**

When multiple groups exist with the same name across different domains in the forest

1. The group will resolve to the group located in the **same domain as the virtual machines**
2. Groups in other domains with identical names will be ignored during resolution

**Example Scenario:**

```
Forest: contoso.com
├── Domain A: us.contoso.com (where AVD VMs are joined)
│   └── Group: "Sales Team" (SID: S-1-5-21-111111...)
└── Domain B: europe.contoso.com  
    └── Group: "Sales Team" (SID: S-1-5-21-222222...)

Result: AVD will resolve "Sales Team" to the group in us.contoso.com
```

**Mitigation Strategies:**

- Ensure unique group names across domains within the forest
- Create groups in the same domain where AVD virtual machines will be joined

**Impact:**

- Incorrect group resolution can result in users being granted or denied access unexpectedly
- Permission assignments may not work as intended if groups are resolved from the wrong domain
- FSLogix profile access may fail if the wrong domain group is resolved

## Workarounds and Best Practices

### For Multi-Domain Forest Deployments

1. **Standardize Group Naming:**
   - Use unique group names across all domains in the forest
   - Implement a naming convention that includes domain context

2. **Centralized Group Management:**
   - Create AVD-specific groups in the same domain as the virtual machines
   - Avoid using existing groups that may exist in multiple domains

## Related Documentation

- [Quick Start Guide - Security Groups](quickStart.md#security-group)
- [Quick Start Guide - Domain Services](quickStart.md#domain-services)
- [Azure Virtual Desktop Identity Options](https://learn.microsoft.com/en-us/azure/virtual-desktop/authentication)
- [FSLogix Profile Management](https://learn.microsoft.com/en-us/fslogix/overview)