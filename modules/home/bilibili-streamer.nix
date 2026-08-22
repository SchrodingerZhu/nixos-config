# Bilibili live-stream management desktop app. Use the native Tauri build: the
# upstream AppImage forces GDK_BACKEND=x11, bypassing niri's Wayland environment
# and producing a blank Xwayland window. Account data already lives under the
# persistent home dataset, so no impermanence entry is needed.
{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  bilibiliStreamer = inputs.bilibili-streamer.packages.${system}.default;
in
{
  home.packages = [ bilibiliStreamer ];
}
