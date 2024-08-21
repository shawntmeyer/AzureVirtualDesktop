param activeDirectoryConnection bool
param fslogixAdminGroupDomainNames array
param fslogixAdminGroupSamAccountNames array
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
param netAppVolumesSubnetResourceId string
param ouPath string
param resourceGroupManagement string
param smbServerLocation string
param storageSku string
param fslogixStorageSolution string
param tagsNetAppAccount object
param timeStamp string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  scope: resourceGroup(split(netAppVolumesSubnetResourceId, '/')[2], split(netAppVolumesSubnetResourceId, '/')[4])
  name: split(netAppVolumesSubnetResourceId, '/')[8]
}

resource netAppAccount 'Microsoft.NetApp/netAppAccounts@2021-06-01' = {
  name: netAppAccountName
  location: location
  tags: tagsNetAppAccount
  properties: {
    activeDirectories: activeDirectoryConnection ? [
      {
        aesEncryption: false
        domain: domainName
        dns: string(vnet.properties.dhcpOptions.dnsServers)
        organizationalUnit: ouPath
        password: domainJoinUserPassword
        smbServerName: 'anf-${smbServerLocation}'
        username: split(domainJoinUserPrincipalName, '@')[0]
      }
    ] : null
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
    subnetId: netAppVolumesSubnetResourceId
    // throughputMibps: int
    // unixPermissions: 'string'
    usageThreshold: 107374182400
    // volumeType: 'string'
  }
}]

module NTFSPermissions '../../../sharedModules/resources/compute/virtual-machine/runCommand/main.bicep' = {
  name: 'DomainJoinNtfsPermissions_${timeStamp}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    location: location
    name: 'NtfsPermissions_${timeStamp}'
    parameters: [
      {
        name: 'AdminGroupDomainNames'
        value: string(fslogixAdminGroupDomainNames)
      }
      {
        name: 'AdminGroupSamAccountNames'
        value: string(fslogixAdminGroupSamAccountNames)
      }
      {
        name: 'FSLogixContainerType'
        value: fslogixContainerType
      }            
      {
        name: 'SmbServerLocation'
        value: smbServerLocation
      }
      {
        name: 'StorageSolution'
        value: fslogixStorageSolution
      }      
    ]
    protectedParameters: [
      {
        name: 'DomainJoinUserPwd'
        value: domainJoinUserPassword
      }
      {
        name: 'DomainJoinUserPrincipalName'
        value: domainJoinUserPrincipalName
      }
    ]
    script: loadTextContent('../../../../.common/scripts/Set-NtfsPermissions.ps1')  
    virtualMachineName: managementVirtualMachineName
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
