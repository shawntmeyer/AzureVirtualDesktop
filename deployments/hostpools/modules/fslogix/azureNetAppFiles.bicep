param artifactsUri string
param artifactsUserAssignedIdentityClientId string
param activeDirectoryConnection string
param delegatedSubnetId string
param dnsServers string
@secure()
param domainJoinUserPassword string
@secure()
param domainJoinUserPrincipalName string
param domainName string
param fileShares array
param fslogixContainerType string
param location string
param managementVirtualMachineName string
param netAppAccountName string
param netAppCapacityPoolName string
param ouPath string
param resourceGroupManagement string
param securityPrincipalNames array
param smbServerLocation string
param storageSku string
param fslogixStorageSolution string
param tagsNetAppAccount object
param timeStamp string

resource netAppAccount 'Microsoft.NetApp/netAppAccounts@2021-06-01' = {
  name: netAppAccountName
  location: location
  tags: tagsNetAppAccount
  properties: {
    activeDirectories: activeDirectoryConnection == 'false' ? null : [
      {
        aesEncryption: false
        domain: domainName
        dns: dnsServers
        organizationalUnit: ouPath
        password: domainJoinUserPassword
        smbServerName: 'anf-${smbServerLocation}'
        username: split(domainJoinUserPrincipalName, '@')[0]
      }
    ]
    encryption: {
      keySource: 'Microsoft.NetApp'
    }
  }
}

resource capacityPool 'Microsoft.NetApp/netAppAccounts/capacityPools@2021-06-01' = {
  parent: netAppAccount
  name: netAppCapacityPoolName
  location: location
  tags: tagsNetAppAccount
  properties: {
    coolAccess: false
    encryptionType: 'Single'
    qosType: 'Auto'
    serviceLevel: storageSku
    size: 4398046511104
  }
}

resource volumes 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes@2021-06-01' = [for i in range(0, length(fileShares)): {
  parent: capacityPool
  name: fileShares[i]
  location: location
  tags: tagsNetAppAccount
  properties: {
    avsDataStore: 'Disabled'
    // backupId: 'string'
    coolAccess: false
    // coolnessPeriod: int
    creationToken: fileShares[i]
    // dataProtection: {
    //   backup: {
    //     backupEnabled: bool
    //     backupPolicyId: 'string'
    //     policyEnforced: bool
    //     vaultId: 'string'
    //   }
    //   replication: {
    //     endpointType: 'string'
    //     remoteVolumeRegion: 'string'
    //     remoteVolumeResourceId: 'string'
    //     replicationId: 'string'
    //     replicationSchedule: 'string'
    //   }
    //   snapshot: {
    //     snapshotPolicyId: 'string'
    //   }
    // }
    defaultGroupQuotaInKiBs: 0
    defaultUserQuotaInKiBs: 0
    encryptionKeySource: 'Microsoft.NetApp'
    // exportPolicy: {
    //   rules: [
    //     {
    //       allowedClients: 'string'
    //       chownMode: 'string'
    //       cifs: bool
    //       hasRootAccess: bool
    //       kerberos5iReadWrite: bool
    //       kerberos5pReadWrite: bool
    //       kerberos5ReadWrite: bool
    //       nfsv3: bool
    //       nfsv41: bool
    //       ruleIndex: int
    //       unixReadWrite: bool
    //     }
    //   ]
    // }
    isDefaultQuotaEnabled: false
    // isRestoring: bool
    kerberosEnabled: false
    ldapEnabled: false
    networkFeatures: 'Standard'
    protocolTypes: [
      'CIFS'
    ]
    securityStyle: 'ntfs'
    serviceLevel: storageSku
    // Enable when GA 
    smbContinuouslyAvailable: true // recommended for FSLogix: https://docs.microsoft.com/en-us/azure/azure-netapp-files/enable-continuous-availability-existing-smb
    smbEncryption: true
    snapshotDirectoryVisible: true
    // snapshotId: 'string'
    subnetId: delegatedSubnetId
    // throughputMibps: int
    // unixPermissions: 'string'
    usageThreshold: 107374182400
    // volumeType: 'string'
  }
}]

module ntfsPermissions 'ntfsPermissions.bicep' = {
  name: 'FslogixNtfsPermissions_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    artifactsUri: artifactsUri
    userAssignedIdentityClientId: artifactsUserAssignedIdentityClientId
    commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Set-NtfsPermissions.ps1 -domainJoinUserPassword "${domainJoinUserPassword}" -domainJoinUserPrincipalName ${domainJoinUserPrincipalName} -fslogixContainerType ${fslogixContainerType} -securityPrincipalNames "${securityPrincipalNames}" -smbServerLocation ${smbServerLocation} -storageSolution ${fslogixStorageSolution}'
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    timeStamp: timeStamp
  }
  dependsOn: [
    volumes
  ]
}

output fileShares array = contains(fslogixContainerType, 'Office') ? [
  volumes[0].properties.mountTargets[0].smbServerFqdn
  volumes[1].properties.mountTargets[0].smbServerFqdn
] : [
  volumes[0].properties.mountTargets[0].smbServerFqdn
]
