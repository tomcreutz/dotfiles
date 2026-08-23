-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("noctalia")
    -- CachyOS allows only the local root user to connect to XWayland. This is
    -- narrower than plain `xhost +` and supports deliberately launched root
    -- GUI tools. Remove it if root GUI/X11 applications are never needed.
    hl.exec_cmd("xhost +SI:localuser:root")
end)
