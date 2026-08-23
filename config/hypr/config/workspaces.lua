-- Workspace rules wiki https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Keep the six purpose-oriented workspaces visible in Noctalia when empty.
local workspaces = {
    { id = "1", name = "web",    layout = "scrolling" }, -- Browser / research
    { id = "2", name = "agents", layout = "scrolling" }, -- Herdr / agents
    { id = "3", name = "code",   layout = "scrolling" }, -- IDE / other work
    { id = "4", name = "chat",   layout = "master" },    -- Communication
    { id = "5", name = "misc",   layout = "dwindle" },   -- Miscellaneous
}

for _, workspace in ipairs(workspaces) do
    hl.workspace_rule({
        workspace = workspace.id,
        default_name = workspace.name,
        layout = workspace.layout,
        persistent = true,
    })
end

-- Fullscreen is a window state rather than a workspace layout. Game window
-- rules route detected games to workspace 6 and make them fullscreen.
hl.workspace_rule({
    workspace = "6",
    default_name = "game",
    persistent = true,
})
