# Fonts: Maple Mono default, Sarasa Gothic/Term families, and Noto fallbacks.
{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      maple-mono.NF-CN # Maple Mono Nerd Font + CN variant (monospace default)
      sarasa-gothic # Sarasa Gothic UI and Term/Mono programming families
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
