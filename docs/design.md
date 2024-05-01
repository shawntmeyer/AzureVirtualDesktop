# Azure Virtual Desktop Solution

[**Home**](../README.md) | [**Features**](./features.md) | [**Design**](./design.md) | [**Prerequisites**](./prerequisites.md) | [**Troubleshooting**](./troubleshooting.md)

## Design

This Azure Virtual Desktop (AVD) solution will deploy fully operational AVD hostpool(s) to an Azure subscription. 

The deployment utilizes the Cloud Adoption Framework naming conventions and organizes resources and resource groups in accordance with several available parameters:

- Business Unit (**businessUnitIdentifier**): This *optional* parameter is primarily designed to allow multiple business units to deploy AVD hostpools into the same subscription. When used, all resources and resource groups contain this string value in the name. All shared resources located in the management and control plane resource groups will also contain this string value. When this parameter value is not specified, it is assumed that the subscription is used by a single business unit and all shared resource groups will not contain a business unit identifier string.

- Host Pool Identifier (**hostpoolIdentifier**): This *required* parameter is used to uniquely identify the hostpool specific resources such as the control plane objects, compute resources, and FSLogix storage resources (when deployed).

- Centralized AVD Monitoring (**centralizedAVDMonitoring**): This *optional* boolean (defaults to True) parameter is only used when the Business Unit Identifier is specified. If set to true, then all monitoring resources are named without the Business Unit Identifier and thus will be shared subscription/region wide. When set to 'False', then the monitoring resources and resource groups are named with the Business Unit Identifier string located in the name and thus only shared across the Business Unit.

![ResourceGroupNaming](images/ResourceGroupNaming.png)

If AVD Private Link is configured, every AVD deployment within the same subscription will share the AVD global workspace.

There will be one feed workspace deployed per region and per Business Unit Identifier (if specified).

![Stamps](../images/stamps.png)

The code is idempotent, allowing you to scale storage and sessions hosts, but the core management resources will persist and update for any subsequent deployments. Some of those resources are the host pool, application group, and log analytics workspace.

Both a personal or pooled host pool can be deployed with this solution. Either option will deploy a desktop application group with a role assignment. You can also deploy the required resources and configurations to fully enable FSLogix. This solution also automates many of the [features](./features.md) that are usually enabled manually after deploying an AVD host pool.

With this solution you can scale up to Azure's subscription limitations. This solution has been updated to allow sharding. A shard provides additional capacity to an AVD hostpool. See the details below for increasing storage capacity.

## Sharding to Increase Storage Capacity

To add storage capacity to an AVD hostpool, the "StorageIndex" and "StorageCount" parameters should be modified to your desired capacity. The last two digits in the name for the chosen storage solution will be incremented between each deployment.

The "VHDLocations" setting will include all the file shares. The "SecurityPrincipalIds" and "SecurityPrincipalNames" will have an RBAC assignment and NTFS permissions set on one storage shard per hostpool. Each user assigned to the hostpool application groups should only have access to one file share. When the user accesses a session host, their profile will load from their respective file share.