-- Workspace rules wiki https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Keep all numbered workspaces visible in Noctalia, including when empty.
for i = 1, NUM_WORKSPACES do
    hl.workspace_rule({
        workspace = tostring(i),
        persistent = true,
    })
end
