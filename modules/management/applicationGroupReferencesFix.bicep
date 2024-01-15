param applicationGroupReferences array

var FixNames = [for ApplicationGroupReference in applicationGroupReferences: replace(replace(ApplicationGroupReference, 'resourcegroups', 'resourceGroups'), 'applicationgroups', 'applicationGroups')]

output applicationGroupReferences array = union(FixNames, [])
