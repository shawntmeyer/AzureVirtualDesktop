param imageDefinitionResourceId string = '/subscriptions/6638b757-bc2e-43a8-9274-1d7e2961563d/resourceGroups/rg-avd-image-management-usw2/providers/Microsoft.Compute/galleries/gal_image_management_usw2/images/vmid-MicrosoftWindowsDesktop-windows11-win1123h2avd'

output features array = reference(imageDefinitionResourceId, '2023-07-03').features
