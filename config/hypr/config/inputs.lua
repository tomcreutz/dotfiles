-- Input configuration

hl.config({
    input = {
        kb_layout = "de",
        -- Global pointer fallback. The touchpad can override this below without
        -- changing the TrackPoint or an external mouse.
        accel_profile = "flat",
    },
    -- Uncomment the section below to enable software cursors; this can help with cursor display or behavior issues
    -- cursor = {
    --     no_hardware_cursors = 1,
    -- },
})

-- Per-device touchpad settings. Find the device name with `hyprctl devices`
-- and set TOUCHPAD_DEVICE in the active machine profile.
-- sensitivity: -1.0 (slower) to 1.0 (faster); 0.0 is unmodified.
if TOUCHPAD_DEVICE and TOUCHPAD_DEVICE ~= "" then
    hl.device({
        name = TOUCHPAD_DEVICE,
        sensitivity = 0.8,
        accel_profile = "flat", -- "flat" or "adaptive"
        natural_scroll = true,
    })
end

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })
