# Fonts: Maple Mono Nerd Font CN as monospace default, Noto CJK fallbacks.
# Attr verified: maple-mono.NF-CN -> MapleMono-NF-CN-7.9.
{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      maple-mono.NF-CN # Maple Mono Nerd Font + CN variant (monospace default)
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      # Family name confirmed post-install via `fc-list | grep -i maple`.
      monospace = [ "Maple Mono NF CN" "Noto Sans Mono CJK SC" ];
      sansSerif = [ "Noto Sans" "Noto Sans CJK SC" ];
      serif = [ "Noto Serif" "Noto Serif CJK SC" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
