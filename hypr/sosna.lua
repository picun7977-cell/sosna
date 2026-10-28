-- «Сосна»: внешний вид окон и слоёв в духе macOS + горячие клавиши оболочки (qs -c sosna)
-- Подключается строкой require("sosna") в ~/.config/hypr/hyprland.lua (это делает install.sh).

-- Матовое стекло: размываем всё, что рисует оболочка, кроме прозрачных областей и мягких теней
hl.layer_rule({ match = { namespace = "sosna-.*" }, blur = true, ignore_alpha = 0.25 })
hl.layer_rule({ match = { namespace = "sosna-(wallpaper|desktop|corners|hotcorner|inhibitor)" }, blur = false })
hl.layer_rule({ match = { namespace = "sosna-(island|dock|bar|corners|hotcorner)" }, no_anim = true })
hl.layer_rule({ match = { namespace = "sosna-(spotlight|switcher|popup)" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "sosna-mission" }, no_anim = true })
hl.layer_rule({ match = { namespace = "sosna-lock" }, no_anim = true })

-- Окна в стиле мака: скругление, тонкая рамка, мягкая тень
hl.config({
    decoration = {
        rounding = 12,
        shadow = { enabled = true, range = 28, render_power = 3, color = "rgba(00000055)" },
    },
    general = { border_size = 1 },
})

-- Окна самой Сосны (Настройки, Звук) — плавающие и стеклянные
hl.window_rule({ match = { class = "org.quickshell", title = "Сосна · .*" }, float = true, center = true, opaque = false })

-- ─────────── Горячие клавиши Сосны (вместо caelestia) ───────────
local function sosna(name) return hl.dsp.global("sosna:" .. name) end
local function ipc(args) return hl.dsp.exec_cmd("qs -c sosna ipc call " .. args) end
os.execute("mkdir -p \"$HOME/.cache/sosna\"")
local log = io.open(os.getenv("HOME") .. "/.cache/sosna/hypr-binds.log", "w")
local function rebind(key, action, opts)
    local ok, err = pcall(hl.unbind, key)
    if log and not ok then log:write("unbind ", key, ": ", tostring(err), "\n") end
    local ok2, err2 = pcall(hl.bind, key, action, opts)
    if log then log:write(ok2 and "ok " or "FAIL ", key, " ", tostring(err2 or ""), "\n") end
end

-- Одиночное нажатие Win: бинд на отпускание шлёт оболочке только «отпущено» (sosna:spotlightTap).
-- Любая другая клавиша или кнопка мыши с зажатым Win отменяет открытие (sosna:spotlightCancel).
rebind("SUPER + SUPER_L", sosna("spotlightTap"), { release = true })
pcall(hl.bind, "SUPER + mouse:272", sosna("spotlightCancel"), { non_consuming = true })
pcall(hl.bind, "SUPER + mouse:273", sosna("spotlightCancel"), { non_consuming = true })
rebind("SUPER + Space", sosna("spotlight"))
rebind("SUPER + V", sosna("clipboard"))
rebind("SUPER + ALT + V", sosna("clipboard"))
rebind("SUPER + Period", sosna("emoji"))
rebind("SUPER + K", sosna("control"))
rebind("SUPER + B", sosna("notifs"))
rebind("SUPER + Tab", sosna("mission"))
rebind("ALT + Tab", sosna("switcher"))
rebind("SHIFT + ALT + Tab", sosna("switcherPrev"))
rebind("SUPER + L", sosna("lock"))
rebind("CTRL + ALT + Delete", sosna("power"))
rebind("SUPER + Comma", sosna("settings"))
rebind("CTRL + ALT + V", sosna("sound"))

-- Скриншоты: Super+Shift+S — заморозка и выделение, Print — весь экран
rebind("Print", ipc("shot full"), { locked = true })
rebind("SUPER + SHIFT + S", ipc("shot area"))
rebind("SUPER + SHIFT + ALT + S", ipc("shot area"))
rebind("SUPER + SHIFT + C", ipc("shot color"))
rebind("SUPER + ALT + R", sosna("record"))
rebind("CTRL + ALT + R", sosna("record"))

-- Яркость монитора (DDC/CI)
rebind("XF86MonBrightnessUp", ipc("brightness up"), { locked = true, repeating = true })
rebind("XF86MonBrightnessDown", ipc("brightness down"), { locked = true, repeating = true })
rebind("SUPER + F2", ipc("brightness up"), { repeating = true })
rebind("SUPER + F1", ipc("brightness down"), { repeating = true })

-- Музыка
for _, k in ipairs({ "XF86AudioPlay", "XF86AudioPause", "CTRL + SUPER + Space" }) do
    rebind(k, sosna("media"), { locked = true })
end
rebind("XF86AudioNext", sosna("mediaNext"), { locked = true })
rebind("CTRL + SUPER + Equal", sosna("mediaNext"), { locked = true })
rebind("XF86AudioPrev", sosna("mediaPrev"), { locked = true })
rebind("CTRL + SUPER + Minus", sosna("mediaPrev"), { locked = true })

-- Перезапуск оболочки
rebind("CTRL + SUPER + SHIFT + R", hl.dsp.exec_cmd("qs -c sosna kill"), { release = true })
rebind("CTRL + SUPER + ALT + R", hl.dsp.exec_cmd("qs -c sosna kill; sleep .2; ~/.local/bin/sosna-start"), { release = true })
rebind("SUPER + ALT + L", hl.dsp.exec_cmd("~/.local/bin/sosna-start"))

if log then log:close() end

-- Событие клавиатуры: (код xkb, время, 1 — нажата / 0 — отпущена).
-- Win + другая клавиша → не открывать Spotlight; отпустили Alt → выбрать окно в Alt+Tab.
local SUPER_L, SUPER_R, ALT_L = 133, 134, 64
local superDown, superUsed = false, false
hl.on("input.keyboard.key", function(code, _, state)
    if code == SUPER_L or code == SUPER_R then
        superDown = state == 1
        if superDown then superUsed = false end
    elseif state == 1 and superDown and not superUsed then
        superUsed = true
        hl.dispatch(sosna("spotlightCancel"))
    end
    if code == ALT_L and state == 0 then
        hl.dispatch(sosna("switcherDone"))
    end
end)

-- Автозапуск оболочки при старте Hyprland
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/sosna-start")
end)
