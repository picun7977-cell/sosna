-- Минимальный конфиг Hyprland для «Сосны» (ставится, только если своего конфига ещё нет).
-- Документация по Lua-конфигу: https://wiki.hypr.land

-- Мониторы: любой подключённый — в родном разрешении
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "20")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle",  -- раскладка: Alt+Shift
        repeat_delay = 250,
        repeat_rate = 35,
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
    general = { gaps_in = 5, gaps_out = 10, layout = "dwindle" },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 20")
end)

-- Окна
hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"))
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + ALT + Space", hl.dsp.window.float())
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
for _, d in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. d, hl.dsp.focus({ direction = d }))
    hl.bind("SUPER + SHIFT + " .. d, hl.dsp.window.move({ direction = d }))
end

-- Рабочие столы: Super+1…9 — перейти, Super+Alt+1…9 — перенести окно
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + ALT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "+1" }))

-- Оболочка «Сосна»: оформление, горячие клавиши, автозапуск
require("sosna")
