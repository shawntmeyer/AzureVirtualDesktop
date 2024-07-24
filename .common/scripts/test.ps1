


function InstallationResultToText($result) {
    switch ($result) {
        2 { return "Succeeded" }
        3 { return "Succeeded with errors" }
        4 { return "Failed" }
        5 { return "Cancelled" }
        default { return "Unexpected ($result)" }
    }
}

function DeploymentActionToText($action) {
    switch ($action) {
        0 { return "None (Inherit)" }
        1 { return "Installation" }
        2 { return "Uninstallation" }
        3 { return "Detection" }
        4 { return "Optional Installation" }
        default { return "Unexpected ($action)" }
    }
}

function UpdateDescription($update) {
    $description = "$($update.Title) {$($update.Identity.UpdateID).$($update.Identity.RevisionNumber)}"
    if ($update.IsHidden) {
        $description += " (hidden)"
    }
    if ($args.Named.Exists("ShowDetails")) {
        if ($update.KBArticleIDs.Count -gt 0) {
            $description += " ("
            for ($i = 0; $i -lt $update.KBArticleIDs.Count; $i++) {
                if ($i -gt 0) {
                    $description += ","
                }
                $description += "KB" + $update.KBArticleIDs.Item($i)
            }
            $description += ")"
        }
        $description += " Categories: "
        for ($i = 0; $i -lt $update.Categories.Count; $i++) {
            $category = $update.Categories.Item($i)
            if ($i -gt 0) {
                $description += ","
            }
            $description += "$($category.Name) {$($category.CategoryID)}"
        }
        $description += " Deployment action: " + (DeploymentActionToText $update.DeploymentAction)
    }
    return $description
}