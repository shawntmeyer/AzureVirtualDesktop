metadata name = 'Deduplicate Storage Accounts by Region'
metadata description = 'This module takes an array of storage Account objects with storage Account Id and location properties. It deduplicates the array based on location (i.e., generates a list of resource Ids that are unique in terms of region).'
metadata owner = 'Shawn Meyer, Microsoft Corporation'

targetScope = 'subscription'

param location string
param storageAccounts array

var inRegion = filter(storageAccounts, sa => sa.location == location)
var vhdStorageAccount = take(inRegion, 1)
var uniqueLocations = reduce(storageAccounts, [], (cur, next) => union(cur,([first(filter(storageAccounts, x => x.location == next.location))])))
var ccStorageAccounts = take(uniqueLocations, 4)

output ccStorageAccountIds array = [for sa in ccStorageAccounts: sa.id]
output vhdStorageAccountId array = [for sa in vhdStorageAccount: sa.id]
