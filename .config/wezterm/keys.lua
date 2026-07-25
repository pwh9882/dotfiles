-- keys.lua — Keybindings (shared + platform-specific, excluding plugins)
local wezterm = require 'wezterm'
local M = {}

local function move_pane(key, direction)
    return {
        key = key,
        mods = 'LEADER',
        action = wezterm.action.ActivatePaneDirection(direction),
    }
end

local function resize_pane(key, direction)
    return {
        key = key,
        action = wezterm.action.AdjustPaneSize { direction, 3 },
    }
end

-- 원격 tmux/TUI가 켠 mouse/focus/paste 리포팅 모드는 SSH가 비정상 종료하면
-- 로컬 터미널에 남아 드래그가 escape code로 입력된다. 셸 프롬프트가 돌아오는
-- pane은 zsh precmd(_term_reset_input_modes)가 정리하지만, ssh를 pane의 프로그램
-- 자체로 띄운 경우엔 정리할 셸이 없다. 터미널에 해제 시퀀스를 직접 주입한다.
--
-- RIS(ESC c)는 확실하지만 화면과 스크롤백까지 지운다. 그래서 여기서는 화면
-- 내용을 건드리지 않는 조각만 모아 RIS에 준하는 범위를 덮는다.
local INPUT_MODE_RESET = table.concat {
    -- DECSTR soft reset: 스크롤 영역, 문자셋 G0-G3, insert/origin/keyboard action
    -- 모드, 커서 표시를 되돌린다. 화면은 지우지 않는다.
    '\x1b[!p',
    -- DECSTR이 autowrap을 끄는 구현이 있어 명시적으로 다시 켠다.
    '\x1b[?7h',
    -- mouse tracking(9, 1000-1003)과 focus reporting(1004).
    '\x1b[?9l\x1b[?1000l\x1b[?1001l\x1b[?1002l\x1b[?1003l\x1b[?1004l',
    -- mouse 좌표 인코딩(1005/1006/1015/1016)과 bracketed paste(2004).
    '\x1b[?1005l\x1b[?1006l\x1b[?1015l\x1b[?1016l\x1b[?2004l',
    -- 키 인코딩: xterm modifyOtherKeys와 kitty keyboard 스택.
    -- modifyOtherKeys가 남으면 Ctrl+U가 \e[27;5;117~로 인코딩된다.
    '\x1b[>4;0m\x1b[<u',
    -- alt screen에 갇힌 경우 주 화면으로 복귀. 주 화면이면 no-op이다.
    '\x1b[?1049l\x1b[?47l',
    -- 커서 표시와 SGR 속성.
    '\x1b[?25h\x1b[m',
    -- 앱이 바꾼 팔레트/전경/배경/커서색을 config 기본값으로 (OSC 104/110-112).
    '\x1b]104\x07\x1b]110\x07\x1b]111\x07\x1b]112\x07',
}

-- WezTerm 기본 바인딩과 같이 shifted 글자는 대소문자 두 형태를 모두 등록한다.
local function reset_input_modes(key)
    return {
        key = key,
        mods = 'LEADER|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            -- inject_output은 local pane 전용이다. mux/ssh domain pane에는
            -- 주입할 경로가 없어 파괴적이지만 확실한 RIS로 물러선다.
            local ok = pcall(function() pane:inject_output(INPUT_MODE_RESET) end)
            if not ok then
                window:perform_action(wezterm.action.ResetTerminal, pane)
            end
        end),
    }
end

function M.apply(config, is_macos)
    -- Leader key
    config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

    -- Shared keybindings
    config.keys = {
        { key = 'a', mods = 'LEADER|CTRL', action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' } },

        move_pane('phys:h', 'Left'),
        move_pane('phys:j', 'Down'),
        move_pane('phys:k', 'Up'),
        move_pane('phys:l', 'Right'),
        move_pane('LeftArrow', 'Left'),
        move_pane('DownArrow', 'Down'),
        move_pane('UpArrow', 'Up'),
        move_pane('RightArrow', 'Right'),

        { key = 'r', mods = 'LEADER', action = wezterm.action.ActivateKeyTable {
            name = 'resize_panes', one_shot = false, timeout_milliseconds = 1000,
        }},

        { key = 'Enter', mods = 'SHIFT', action = wezterm.action { SendString = "\x1b\r" } },

        -- 끊긴 SSH가 남긴 mouse/focus 리포팅 해제 (Ctrl+A, Shift+R)
        reset_input_modes('r'),
        reset_input_modes('R'),

        -- tmux prefix indicator (Ctrl+B → pass through + show badge)
        { key = 'b', mods = 'CTRL', action = wezterm.action.Multiple({
            wezterm.action.SendKey { key = 'b', mods = 'CTRL' },
            wezterm.action.ActivateKeyTable {
                name = 'tmux_prefix', timeout_milliseconds = 2000,
            },
        })},
    }

    -- Platform-specific keybindings
    if is_macos then
        -- Pane splits
        table.insert(config.keys, { key = '"', mods = 'LEADER', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } })
        table.insert(config.keys, { key = '%', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } })

        -- Word/line navigation
        table.insert(config.keys, { key = 'LeftArrow', mods = 'OPT', action = wezterm.action.SendString '\x1bb' })
        table.insert(config.keys, { key = 'RightArrow', mods = 'OPT', action = wezterm.action.SendString '\x1bf' })
        table.insert(config.keys, { mods = 'CMD', key = 'LeftArrow', action = wezterm.action.SendKey({ mods = 'CTRL', key = 'a' }) })
        table.insert(config.keys, { mods = 'CMD', key = 'RightArrow', action = wezterm.action.SendKey({ mods = 'CTRL', key = 'e' }) })
        table.insert(config.keys, { mods = 'CMD', key = 'Backspace', action = wezterm.action.SendKey({ mods = 'CTRL', key = 'u' }) })

        -- Tab navigation
        table.insert(config.keys, { mods = 'CMD|ALT', key = 'LeftArrow', action = wezterm.action.ActivateTabRelative(-1) })
        table.insert(config.keys, { mods = 'CMD|ALT', key = 'RightArrow', action = wezterm.action.ActivateTabRelative(1) })

        -- Open config in nvim
        table.insert(config.keys, { key = ',', mods = 'SUPER', action = wezterm.action.SpawnCommandInNewTab {
            cwd = wezterm.home_dir, args = { 'nvim', wezterm.config_file },
        }})

        -- Project picker
        local projects_ok, projects = pcall(require, 'projects')
        if projects_ok then
            table.insert(config.keys, { key = 'p', mods = 'LEADER', action = projects.choose_project() })
        end
    else
        -- Pane splits (LEADER|SHIFT needed on Windows)
        table.insert(config.keys, { key = '"', mods = 'LEADER|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } })
        table.insert(config.keys, { key = '%', mods = 'LEADER|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } })

        -- Tab navigation
        table.insert(config.keys, { key = 'LeftArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(-1) })
        table.insert(config.keys, { key = 'RightArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(1) })

        -- Command palette & launcher
        table.insert(config.keys, { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCommandPalette })
        table.insert(config.keys, { key = 'l', mods = 'ALT', action = wezterm.action.ShowLauncherArgs {
            flags = 'FUZZY|TABS|LAUNCH_MENU_ITEMS|DOMAINS|WORKSPACES',
        }})
    end

    -- Key tables (shared)
    config.key_tables = {
        resize_panes = {
            resize_pane('j', 'Down'),
            resize_pane('k', 'Up'),
            resize_pane('h', 'Left'),
            resize_pane('l', 'Right'),
        },
        tmux_prefix = {},  -- empty: all keys pass through to tmux, badge shown until timeout
    }
end

return M
