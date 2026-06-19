# WezTerm with the WebGpu front-end (good for the AMD iGPU).
{ ... }:
{
  programs.wezterm = {
    enable = true;
    # `wezterm` is already in scope (the HM module prepends `local wezterm = require 'wezterm'`).
    extraConfig = ''
      local config = wezterm.config_builder()

      config.front_end = "WebGpu"
      config.enable_wayland = true

      config.font = wezterm.font_with_fallback({
        "Maple Mono NF CN",
        "Noto Sans Mono CJK SC",
      })
      config.font_size = 12.0

      config.hide_tab_bar_if_only_one_tab = true
      config.window_background_opacity = 0.96

      return config
    '';
  };
}
