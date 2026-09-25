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
wezterm.on("gui-startup", function(cmd)
	-- 遍历，找到对应的显示器名称
	local screen
	local screens = wezterm.gui.screens().by_name
	for name_tmp, screen_tmp in pairs(screens) do
		if name_tmp == current_screen then
			-- 此处给全局变量 current_screen 赋值了，在“update-status”事件中有用到
			current_screen = name_tmp
			screen = screen_tmp
		end
	end

	-- 如果找不到指定显示器，就取默认值 main
	if screen == nil then
		screen = wezterm.gui.screens().main
	end

	-- 初始化窗口
	local width_ratio = 0.74
	local height_ratio = 0.69
	local width, height = screen.width * width_ratio, screen.height * height_ratio
	-- local width, height = 800, 500 --指定窗口宽高，单位 px
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {
		-- width = 50,  -- 这个长宽是行列数，不适合用来计算
		-- height = 30,
		position = {
			x = (screen.width - width) / 2,
			y = (screen.height - height) / 2 * 0.65, -- 乘以 0.65 让窗口稍微偏上一些更舒适
			origin = { Named = screen.name },
		},
	})
	window:gui_window():set_inner_size(width, height) -- 这里的长宽单位是 px
end)

-- 字体
-- macOS 需安装同名字体（brew 无对应 cask，下载后放入 ~/Library/Fonts/）：
--   Cascadia Mono NF: https://github.com/microsoft/cascadia-code/releases （取 zip 内 ttf/CascadiaMonoNF.ttf）
--   LXGW WenKai Mono GB Screen: https://github.com/lxgw/LxgwWenKai-Screen/releases
-- 未安装时按顺序回退（可先 brew install --cask font-cascadia-mono font-lxgw-wenkai-gb 过渡，但无 Nerd Font 图标）
-- M.font = wezterm.font("FiraCode Nerd Font")
M.font = wezterm.font_with_fallback({
	"Cascadia Mono NF",
	"LXGW WenKai Mono GB Screen",
	-- macOS 兜底字体（近亲命名，无 Nerd Font 图标）
	"Cascadia Mono",
	"LXGW WenKai Mono GB",
})
-- M.font = wezterm.font_with_fallback({ "FiraCode Nerd Font", "LXGW WenKai Mono GB Screen" })
M.font_size = 12

-- 关闭时不进行确认
-- M.window_close_confirmation = "NeverPrompt"

-- 配色
local materia = wezterm.color.get_builtin_schemes()["Material Darker (base16)"]
local catppuccin = wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]
M.colors = catppuccin

M.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
M.window_frame = {
	active_titlebar_bg = "#353543",
	inactive_titlebar_bg = "#353543",
}
if is_darwin then
	-- macOS：左上角原生"红绿灯"按钮
	M.integrated_title_button_alignment = "Left"
	M.integrated_title_button_style = "MacNative"
	M.integrated_title_buttons = { "Close", "Hide", "Maximize" }
else
	M.integrated_title_button_alignment = "Right"
	M.integrated_title_button_style = "Windows"
	M.integrated_title_buttons = { "Hide", "Maximize", "Close" }
end
M.adjust_window_size_when_changing_font_size = false

-- macOS：把 Option 键当作 Alt，否则 Alt+hjkl 等 pane 快捷键会变成特殊字符输入
-- 注意：nightly 已移除 macos_option_as_alt 选项，改用下面两个细粒度选项
-- （两端均可设置，Windows 端无副作用；副作用是 macOS 上无法再用 Option+键 输入特殊符号）
M.send_composed_key_when_left_alt_is_pressed = false
M.send_composed_key_when_right_alt_is_pressed = false

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

-- 取消所有默认的热键
M.disable_default_key_bindings = true
local act = wezterm.action
M.keys = {
	-- Ctrl+Shift+Tab 遍历 tab
	{ key = "Tab", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(1) },
	-- F11 切换全屏
	{ key = "F11", mods = "NONE", action = act.ToggleFullScreen },
	-- Leader + t:切换标签栏显示 / 隐藏
	{ key = "F12", mods = "NONE", action = wezterm.action.EmitEvent("toggle-tab-bar") },
	-- Ctrl+Shift++ 字体增大
	{ key = "+", mods = "SHIFT|CTRL", action = act.IncreaseFontSize },
	-- Ctrl+Shift+- 字体减小
	{ key = "_", mods = "SHIFT|CTRL", action = act.DecreaseFontSize },
	-- Ctrl+Shift+C 复制选中区域
	{ key = "C", mods = "SHIFT|CTRL", action = act.CopyTo("Clipboard") },
	-- Ctrl+Shift+N 新窗口
	{ key = "N", mods = "SHIFT|CTRL", action = act.SpawnWindow },
	-- Ctrl+Shift+T 新 tab
	{ key = "T", mods = "SHIFT|CTRL", action = act.ShowLauncher },
	-- Ctrl+Shift+Enter 显示启动菜单
	{
		key = "Enter",
		mods = "SHIFT|CTRL",
		action = act.ShowLauncherArgs({ flags = "FUZZY|TABS|LAUNCH_MENU_ITEMS|DOMAINS" }),
	},
	-- Ctrl+Shift+V 粘贴剪切板的内容
	{ key = "V", mods = "SHIFT|CTRL", action = act.PasteFrom("Clipboard") },
	-- Ctrl+Shift+R 手动重载配置（配置出错后的逃生键；保存配置文件也会自动热重载）
	{ key = "R", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
	-- Ctrl+Shift+W 关闭 tab 且不进行确认
	{ key = "W", mods = "SHIFT|CTRL", action = act.CloseCurrentTab({ confirm = false }) },
	-- Ctrl+Shift+L 切换标签页
	{ key = "H", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(-1) },
	{ key = "L", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(1) },
	{ key = '"', mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "%", mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "LeftArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
	{ key = "h", mods = "ALT", action = act.ActivatePaneDirection("Left") },
	{ key = "l", mods = "ALT", action = act.ActivatePaneDirection("Right") },
	{ key = "k", mods = "ALT", action = act.ActivatePaneDirection("Up") },
	{ key = "j", mods = "ALT", action = act.ActivatePaneDirection("Down") },
	-- Alt+p 打开 pane 选择器：数字标签直接跳到任意分屏（多 pane 时最顺手）
	{ key = "p", mods = "ALT", action = act.PaneSelect({ alphabet = "1234567890" }) },
	-- Alt+z 当前 pane 全屏/还原（tmux 风格 zoom，干活时放大、再按回来）
	{ key = "z", mods = "ALT", action = act.TogglePaneZoomState },
	-- Alt+x 关闭当前 pane
	{ key = "x", mods = "ALT", action = act.CloseCurrentPane({ confirm = false }) },
	-- Ctrl+Alt+hjkl 调整 pane 大小（不用 Alt+Shift：那是 Windows 输入法切换热键）
	{ key = "h", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "j", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
	{ key = "k", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
	{ key = "l", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Right", 5 }) },
	-- Alt+o 和选中的 pane 交换位置；Alt+r 顺时针轮换
	{ key = "o", mods = "ALT", action = act.PaneSelect({ mode = "SwapWithActive" }) },
	{ key = "r", mods = "ALT", action = act.RotatePanes("Clockwise") },
}

-- macOS 端补充 Cmd 快捷键（disable_default_key_bindings 会把默认的 Cmd 快捷键也一并清掉）
if is_darwin then
	local mac_keys = {
		-- Cmd+C / Cmd+V 复制粘贴
		{ key = "C", mods = "SUPER", action = act.CopyTo("Clipboard") },
		{ key = "V", mods = "SUPER", action = act.PasteFrom("Clipboard") },
		-- Cmd+N 新窗口；Cmd+T 新 tab（启动器）
		{ key = "N", mods = "SUPER", action = act.SpawnWindow },
		{ key = "T", mods = "SUPER", action = act.ShowLauncher },
		-- Cmd+W 关闭 tab
		{ key = "W", mods = "SUPER", action = act.CloseCurrentTab({ confirm = false }) },
		-- Cmd+Shift+[ / ] 切换标签页（macOS 惯例）
		{ key = "[", mods = "SUPER|SHIFT", action = act.ActivateTabRelative(-1) },
		{ key = "]", mods = "SUPER|SHIFT", action = act.ActivateTabRelative(1) },
		-- Cmd+D 左右分屏 / Cmd+Shift+D 上下分屏（iTerm2 习惯）
		{ key = "D", mods = "SUPER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "D", mods = "SUPER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	}
	for _, k in ipairs(mac_keys) do
		table.insert(M.keys, k)
	end
end

return M
