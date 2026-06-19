# Zen Browser (Twilight) as the system default browser. Replaces Firefox.
# Profile data lives under ~/.zen (in /home, persistent) — survives the wipe.
{ ... }:
let
  # The Twilight channel installs `zen-twilight` with desktop id zen-twilight.desktop.
  zenDesktop = "zen-twilight.desktop";
in
{
  programs.zen-browser.enable = true;

  # CLI callers ($BROWSER) -> Zen.
  home.sessionVariables.BROWSER = "zen-twilight";

  # Default associations so links from DMS/vicinae/terminal open in Zen.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = zenDesktop;
      "x-scheme-handler/https" = zenDesktop;
      "text/html" = zenDesktop;
      "x-scheme-handler/about" = zenDesktop;
      "x-scheme-handler/unknown" = zenDesktop;
    };
  };
}
