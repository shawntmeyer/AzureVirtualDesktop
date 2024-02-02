param storageAccounts array = [
  {
  name: 'storageName1'
  location: 'eastus'
}
{
  name: 'storageName2'
  location: 'eastus'
}
{
  name: 'storageName3'
  location: 'westus'
}
]

output locations array = [for item in storageAccounts: item.location] 
output uniqueLocations array = reduce(storageAccounts, [], (cur, next) => union(cur,([first(filter(storageAccounts, x => x.location == next.location))])))
