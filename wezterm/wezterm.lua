local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

config.automatically_reload_config = true
config.font_size = 12.0
config.use_ime = true
config.window_background_opacity = 0.75
config.macos_window_background_blur = 0
config.adjust_window_size_when_changing_font_size = true

config.initial_cols = 120
config.initial_rows = 30

----------------------------------------------------
-- OrbStack 接続設定
----------------------------------------------------
-- config.ssh_domains = {
--   {
--     name = 'orbstack-ubuntu',
--     -- OrbStackの仮想マシン名 + .orb.local (例: ubuntu.orb.local)
--     -- もしくは IPアドレス (192.168.139.202) のままでもOKです
--     remote_address = 'ubuntu.orb.local',
--     username = 'keita', -- OrbStack内のユーザー名
--   },
-- }

local is_windows = wezterm.target_triple:find("windows") ~= nil

if is_windows then
  -- Windows: open the WSL distribution (Ubuntu) directly.
  local wsl = wezterm.default_wsl_domains()
  if #wsl > 0 then
    config.default_domain = wsl[1].name
  end
else
  config.default_prog = {
    '/bin/zsh',
    '-lc',
    'ssh ubuntu@orb; exec /bin/zsh -l'
  }
end

config.debug_key_events = true

----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
config.window_decorations = "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- タブが一つの時は非表示
config.hide_tab_bar_if_only_one_tab = true

-- タブバーの透過
config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false
-- タブの閉じるボタンを非表示
-- (nightly builds only; the stable release 20240203 rejects this option)
if (tonumber(wezterm.version:sub(1, 8)) or 0) > 20240203 then
  config.show_close_tab_button_in_tabs = false
end

-- タブ同士の境界線を非表示
config.colors = {
  tab_bar = {
    inactive_tab_edge = "none",
  },
}

wezterm.on("gui-startup", function(cmd)
  local screen = wezterm.gui.screens().main
  local ratio = 0.85
  local width, height = screen.width * ratio, screen.height * ratio
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {
    position = { x = (screen.width - width + 450) / 2, y = (screen.height - height + 200) / 2 },
  })
  window:gui_window():set_inner_size(width, height)
end)

-- タブの形をカスタマイズ
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local background = "#5c6d74"
  local foreground = "#FFFFFF"
  local edge_background = "none"
  if tab.is_active then
    background = "#ae8b2d"
    foreground = "#FFFFFF"
  end
  local edge_foreground = background
  local title = "   " .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. "   "
  return {
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_LEFT_ARROW },
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = title },
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_RIGHT_ARROW },
  }
end)

config.window_background_gradient = {
  orientation = 'Vertical',
  colors = {
    '#0f0c29',
    '#302b63',
    '#24243e',
  },
  interpolation = 'Linear',
  blend = 'Rgb',
}

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true

-- keybinds.lua から読み込んだ既存のキーバインドを取得
local custom_keys = require("keybinds").keys or {}

-- 1. 全画面表示 (Cmd + F)
table.insert(custom_keys, { key = 'f', mods = 'CMD', action = act.ToggleFullScreen })

-- 2. 左右画面分割 (Cmd + Q)
table.insert(custom_keys, {
  key = 'q',
  mods = 'CMD',
  action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
})

-- 3. 上下画面分割 (Cmd + B)
table.insert(custom_keys, {
  key = 'b',
  mods = 'CMD',
  action = act.SplitVertical { domain = 'CurrentPaneDomain' },
})

-- 4. 画面（ペイン）直接移動 (Cmd + U/I/O/P)
table.insert(custom_keys, { key = 'u', mods = 'CMD', action = act.ActivatePaneByIndex(0) }) -- 1番目の画面へ
table.insert(custom_keys, { key = 'i', mods = 'CMD', action = act.ActivatePaneByIndex(1) }) -- 2番目の画面へ
table.insert(custom_keys, { key = 'o', mods = 'CMD', action = act.ActivatePaneByIndex(2) }) -- 3番目の画面へ
table.insert(custom_keys, { key = 'p', mods = 'CMD', action = act.ActivatePaneByIndex(3) }) -- 4番目の画面へ

-- 5. 分割画面（ペイン）の削除 (Cmd + Ctrl + Q)
table.insert(custom_keys, { key = 'm', mods = 'CMD', action = act.CloseCurrentPane { confirm = false } })

config.keys = custom_keys
config.key_tables = require("keybinds").key_tables

table.insert(custom_keys, {
  key = "¥",
  mods = "ALT",
  action = act.SendString("\\"),
})

----------------------------------------------------
-- Windows: the Win key belongs to the OS, so use Alt where macOS uses Cmd.
----------------------------------------------------
if is_windows then
  for _, k in ipairs(config.keys) do
    if k.mods then
      k.mods = k.mods:gsub("SUPER", "ALT"):gsub("CMD", "ALT")
    end
  end
end

return config
