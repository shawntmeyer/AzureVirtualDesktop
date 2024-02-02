metadata name = 'Deduplicate Storage Accounts by Region'
metadata description = 'This module takes an array of storage Account objects with storage Account Id and location properties. It deduplicates the array based on location (i.e., generates a list of resource Ids that are unique in terms of region).'
metadata owner = 'Shawn Meyer, Microsoft Corporation'

targetScope = 'subscription'

param storageAccounts array

var uniqueLocations = reduce(storageAccounts, [], (cur, next) => union(cur,([first(filter(storageAccounts, x => x.location == next.location))])))

output storageAccountIds array = [for storageAccount in uniqueLocations: storageAccount.id]
