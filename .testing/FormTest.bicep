param existingreferences array = [
  '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourcegroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-pool5-use2'
  '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourcegroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-pool7-use2'
  '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourcegroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-pool10-use2'
  '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourcegroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-pool8-use2'
  '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourcegroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-pool6-use2'
  '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourcegroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-pool4-use2'
  '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourcegroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationgroups/vddag-pool9-use2'
]

param newreference string = '/subscriptions/67edfd17-f0d1-466a-aacb-ca9daeabb9b8/resourceGroups/rg-avd-control-plane-use2/providers/Microsoft.DesktopVirtualization/applicationGroups/vddag-pool9-use2'

output newreferences array = union(existingreferences, [newreference])

output intersection array = intersection(existingreferences, [newreference])
