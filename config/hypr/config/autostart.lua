-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    -- Initialize KWallet first, then start workspace applications through UWSM
    -- in deterministic order. Noctalia itself uses its XDG autostart entry.
    hl.exec_cmd("$HOME/.config/hypr/scripts/start-session-apps.sh")

    -- CachyOS allows only the local root user to connect to XWayland. This is
    -- narrower than plain `xhost +` and supports deliberately launched root
    -- GUI tools. Remove it if root GUI/X11 applications are never needed.
    hl.exec_cmd("xhost +SI:localuser:root")
end)
