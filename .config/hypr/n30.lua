-- KEY BINDINGS
-- PrintScreen key pressed -> the currently focused monitor (the one containing the cursor) is captured, and the Flameshot GUI is brought up for annotating, cropping, etc.
hl.bind("Print", function()
    local mon = hl.get_active_monitor()
    local n = mon and mon.id or 0
    hl.exec_cmd("flameshot screen --number " .. n .. " --edit")
end)

-- WINDOW RULES
hl.window_rule({
    match       = { class = "flameshot" },
    no_anim     = true,
    pin         = true,
    float       = true,
    decorate    = false,
    no_blur     = true,
    no_shadow   = true,
})
hl.window_rule({
    match   = { class = "flameshot", title = "flameshot" },
    move    = { 0, 0 },
})
hl.window_rule({
    match = { class = "flameshot", title = "flameshot-pin" },
    move  = { "cursor_x-(window_w*0.5)", "cursor_y-(window_h*0.5)" },
})