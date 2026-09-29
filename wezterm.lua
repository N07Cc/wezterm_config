local M = {}
local wezterm = require("wezterm")
if wezterm.config_builder then
	M = wezterm.config_builder()
end

-- 平台判断（Windows / macOS 共用这份配置）
local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_darwin = wezterm.target_triple:find("darwin") ~= nil

-- 初始大小
-- M.initial_cols = 120
-- M.initial_rows = 30
-- 启动监听，初始化窗口
wezterm.on("format-window-title", function()
	return ""
end)

wezterm.on("gui-startup", function(cmd)
	local screen = wezterm.gui.screens().main

	-- 初始化窗口
	local width_ratio = 0.74
	local height_ratio = 0.69
	local width, height = screen.width * width_ratio, screen.height * height_ratio
	-- local width, height = 800, 500 --指定窗口宽高，单位 px
	local spawn_args = cmd or {}
	spawn_args.position = {
		x = (screen.width - width) / 2,
		y = (screen.height - height) / 2 * 0.65, -- 乘以 0.65 让窗口稍微偏上一些更舒适
		origin = { Named = screen.name },
	}
	local _, _, window = wezterm.mux.spawn_window(spawn_args)
	window:gui_window():set_inner_size(width, height) -- 这里的长宽单位是 px
end)

-- 字体
if is_darwin then
	M.font = wezterm.font_with_fallback({
		"JetBrainsMono Nerd Font",
		"PingFang SC",
	})
else
	M.font = wezterm.font_with_fallback({
		"Cascadia Mono NF",
		"LXGW WenKai Mono GB Screen",
		"Cascadia Mono",
		"LXGW WenKai Mono GB",
	})
end
M.font_size = 13

-- 关闭时不进行确认
-- M.window_close_confirmation = "NeverPrompt"

-- 配色
local catppuccin = wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]
M.colors = catppuccin

if is_darwin then
	M.window_decorations = "TITLE|RESIZE|MACOS_USE_BACKGROUND_COLOR_AS_TITLEBAR_COLOR"
	-- 让 ToggleFullScreen 走与左上角绿色按钮相同的 macOS 原生全屏流程。
	-- 非原生全屏会临时移除窗口装饰，在当前 nightly 退出后可能无法正确恢复标题栏 UI。
	M.native_macos_fullscreen_mode = true
else
	M.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
	M.window_frame = {
		active_titlebar_bg = "#353543",
		inactive_titlebar_bg = "#353543",
	}
	M.integrated_title_button_alignment = "Right"
	M.integrated_title_button_style = "Windows"
	M.integrated_title_buttons = { "Hide", "Maximize", "Close" }
end
M.adjust_window_size_when_changing_font_size = false

-- macOS：左 Option 作为 Alt 供 pane 快捷键使用；右 Option 保留特殊字符/重音输入
if is_darwin then
	M.send_composed_key_when_left_alt_is_pressed = false
	M.send_composed_key_when_right_alt_is_pressed = true
end

-- 光标
M.default_cursor_style = "SteadyBar"

-- kitty 键盘协议：nvim(>=0.10) 等应用可拿到完整组合键（区分 <C-h> 和 <BS> 等）
-- 不申请该协议的程序（Nushell/PowerShell 等）行为不受影响
-- ⚠️ 2026-09-26 暂时关闭：nightly 在协议激活时会丢弃 IME 提交的单个中文字符
--   上游 bug：encode_kitty() 对单字符 Composed 事件编码为空串，静默丢弃
--   修复 PR #7944 / #7915 尚未合并；合并出新 nightly 后改回 true 即可
M.enable_kitty_keyboard = false

-- tab bar
M.enable_tab_bar = false
-- M.hide_tab_bar_if_only_one_tab = true
wezterm.on("toggle-tab-bar", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if overrides.enable_tab_bar == nil then
		overrides.enable_tab_bar = not M.enable_tab_bar
	else
		overrides.enable_tab_bar = not overrides.enable_tab_bar
	end
	window:set_config_overrides(overrides)
end)

-- 透明背景
-- M.window_background_opacity = 0.9
-- 设置 pad 为0
M.window_padding = { left = 6, right = 6, top = 6, bottom = 6 }
-- 禁用滚动条
M.enable_scroll_bar = false

-- 默认启动的 shell（按平台区分）
-- M.default_prog = { "D:/Scoop/apps/pwsh/current/pwsh.exe" }
if is_windows then
	M.default_prog = { "D:/Scoop/apps/nu/current/nu.exe" }
elseif is_darwin then
	-- macOS：装了 Homebrew 版 Nushell 则沿用，否则留空 = 使用默认登录 shell（通常是 zsh）
	local nu = wezterm.glob("/opt/homebrew/bin/nu")[1] or wezterm.glob("/usr/local/bin/nu")[1]
	if nu then
		M.default_prog = { nu }
	end
end

-- 启动菜单的一些启动项（按平台区分）
if is_windows then
	M.launch_menu = {
		{ label = "PowerShell 7", args = { "D:/Scoop/apps/pwsh/current/pwsh.exe" } },
		{ label = "Nushell", args = { "D:/Scoop/apps/nu/current/nu.exe" } },
		{ label = "PowerShell", args = { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" } },
		{ label = "CMD", args = { "cmd.exe" } },
	}
else
	M.launch_menu = {
		{ label = "Zsh", args = { "/bin/zsh", "-l" } },
		{ label = "Bash", args = { "/bin/bash", "-l" } },
	}
	-- macOS 上如果找到了 Nushell，加入启动菜单
	if M.default_prog and is_darwin then
		table.insert(M.launch_menu, { label = "Nushell", args = M.default_prog })
	end
end

-- 保留 WezTerm 默认快捷键：macOS 使用 Cmd，Windows 使用 Ctrl+Shift 完成复制、
-- 粘贴、新建/关闭 tab、新窗口、搜索等常用操作。这里只添加跨平台 pane 操作和平台差异项。
M.disable_default_key_bindings = false
local act = wezterm.action

local common_keys = {
	-- 两端一致的窗口操作
	{ key = "F11", mods = "NONE", action = act.ToggleFullScreen },
	{ key = "F12", mods = "NONE", action = act.EmitEvent("toggle-tab-bar") },
	{
		key = "Enter",
		mods = "SHIFT|CTRL",
		action = act.ShowLauncherArgs({ flags = "FUZZY|TABS|LAUNCH_MENU_ITEMS|DOMAINS" }),
	},

	-- 两端一致的 pane 导航与管理
	{ key = "h", mods = "ALT", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "ALT", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "ALT", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "ALT", action = act.ActivatePaneDirection("Right") },
	{ key = "p", mods = "ALT", action = act.PaneSelect({ alphabet = "1234567890" }) },
	{ key = "z", mods = "ALT", action = act.TogglePaneZoomState },
	{ key = "x", mods = "ALT", action = act.CloseCurrentPane({ confirm = false }) },
	{ key = "o", mods = "ALT", action = act.PaneSelect({ mode = "SwapWithActive" }) },
	{ key = "r", mods = "ALT", action = act.RotatePanes("Clockwise") },

	-- 两端一致的 pane 尺寸调整
	{ key = "h", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "j", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
	{ key = "k", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
	{ key = "l", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Right", 5 }) },
}

local mac_keys = {
	-- 使用 macOS 原生全屏流程；F11 仍可作为跨平台备用键
	{ key = "f", mods = "CTRL|SUPER", action = act.ToggleFullScreen },
	-- iTerm2 风格分屏：Cmd+d 左右，Cmd+Shift+d 上下
	{ key = "d", mods = "SUPER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "SUPER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "h", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
	{ key = "l", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },
	{ key = "phys:LeftBracket", mods = "SUPER", action = act.ActivatePaneDirection("Prev") },
	{ key = "phys:RightBracket", mods = "SUPER", action = act.ActivatePaneDirection("Next") },
}

local windows_keys = {
	-- Windows 分屏：Alt+d 左右，Alt+Shift+d 上下
	{ key = "d", mods = "ALT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "ALT|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	-- 对应 macOS 的 Cmd+[/]：循环切换 pane（phys: 避开中文输入法把 [ 改写成 【）
	{ key = "phys:LeftBracket", mods = "ALT", action = act.ActivatePaneDirection("Prev") },
	{ key = "phys:RightBracket", mods = "ALT", action = act.ActivatePaneDirection("Next") },
	-- 对应 macOS 的 Cmd+Shift+[/]：切换 tab
	{ key = "phys:LeftBracket", mods = "ALT|SHIFT", action = act.ActivateTabRelative(-1) },
	{ key = "phys:RightBracket", mods = "ALT|SHIFT", action = act.ActivateTabRelative(1) },
}

M.keys = {}
local function append_keys(keys)
	for _, key_binding in ipairs(keys) do
		table.insert(M.keys, key_binding)
	end
end

append_keys(common_keys)
if is_darwin then
	append_keys(mac_keys)
elseif is_windows then
	append_keys(windows_keys)
end

return M
