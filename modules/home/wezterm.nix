# Shared WezTerm styling for the laptop and workstation under niri.
{ ... }:
{
  programs.wezterm = {
    enable = true;
    # Home Manager prepends `local wezterm = require 'wezterm'`.
    extraConfig = ''
      local config = wezterm.config_builder()

      config.front_end = "WebGpu"
      config.enable_wayland = true

      config.font = wezterm.font_with_fallback({
        "Maple Mono NF CN",
        "Noto Sans Mono CJK SC",
        "Noto Color Emoji",
      })
      config.font_size = 12.0
      config.line_height = 1.10

      config.color_scheme = "Catppuccin Mocha"
      config.window_background_opacity = 0.90
      -- niri supports the ext-background-effect protocol natively.
      config.wayland_window_background_blur = true
      config.window_decorations = "RESIZE"
      config.window_padding = {
        left = 16,
        right = 16,
        top = 12,
        bottom = 12,
      }

      config.hide_tab_bar_if_only_one_tab = false
      config.use_fancy_tab_bar = true
      config.show_new_tab_button_in_tab_bar = false
      config.show_close_tab_button_in_tabs = false
      config.tab_max_width = 28
      config.window_frame = {
        font = wezterm.font("Maple Mono NF CN", { weight = "DemiBold" }),
        font_size = 10.0,
        active_titlebar_bg = "#181825",
        inactive_titlebar_bg = "#181825",
      }
      config.colors = {
        visual_bell = "#45475a",
        tab_bar = {
          background = "#181825",
          active_tab = {
            bg_color = "#313244",
            fg_color = "#cdd6f4",
            intensity = "Bold",
          },
          inactive_tab = {
            bg_color = "#181825",
            fg_color = "#a6adc8",
          },
          inactive_tab_hover = {
            bg_color = "#1e1e2e",
            fg_color = "#cdd6f4",
          },
        },
      }

      -- Eased cursor and bell animations run only while needed.
      config.animation_fps = 60
      config.max_fps = 120
      config.default_cursor_style = "BlinkingBar"
      config.cursor_blink_rate = 800
      config.cursor_blink_ease_in = "EaseInOut"
      config.cursor_blink_ease_out = "EaseInOut"
      config.audible_bell = "Disabled"
      config.visual_bell = {
        fade_in_duration_ms = 75,
        fade_out_duration_ms = 200,
        fade_in_function = "EaseIn",
        fade_out_function = "EaseOut",
      }
      config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.85 }

      local nf = wezterm.nerdfonts
      local process_icons = {
        fish = nf.cod_terminal,
        bash = nf.cod_terminal,
        nvim = nf.custom_vim,
        vim = nf.custom_vim,
        git = nf.dev_git,
        ssh = nf.md_console_network,
        nix = nf.linux_nixos,
      }

      wezterm.on("format-tab-title", function(tab)
        local pane = tab.active_pane
        local process = (pane.foreground_process_name or ""):match("([^/]+)$") or ""
        local icon = process_icons[process] or nf.cod_terminal
        local title = tab.tab_title
        if not title or title == "" then
          title = pane.title
        end
        local activity = ""
        for _, p in ipairs(tab.panes) do
          if p.has_unseen_output then
            activity = " •"
            break
          end
        end
        return {
          { Text = " " .. (tab.tab_index + 1) .. "  " .. icon .. "  "
              .. wezterm.truncate_right(title, 28) .. activity .. " " },
        }
      end)

      config.status_update_interval = 1000
      wezterm.on("update-status", function(window, pane)
        local workspace = window:active_workspace()
        local tab = window:active_tab()
        for _, p in ipairs(tab:panes_with_info()) do
          if p.is_zoomed then
            workspace = workspace .. " · ZOOM"
            break
          end
        end
        window:set_right_status(wezterm.format({
          { Foreground = { Color = "#cba6f7" } },
          { Text = "  " .. nf.cod_layers .. " " .. workspace },
          { Foreground = { Color = "#a6adc8" } },
          { Text = "  " .. nf.md_clock_outline .. " " .. wezterm.strftime("%H:%M") .. "  " },
        }))
      end)

      local act = wezterm.action
      config.keys = {
        { key = "Enter", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
        { key = "Enter", mods = "CTRL|ALT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
        { key = "s", mods = "CTRL|SHIFT", action = act.PaneSelect({ mode = "Activate" }) },
        { key = "w", mods = "CTRL|ALT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
      }

      return config
    '';
  };
}
