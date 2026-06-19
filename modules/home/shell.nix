# Interactive shell: fish + atuin + starship, wired via their HM modules so the
# fish init is injected and ordered correctly.
#
# Persistence: atuin history (~/.local/share/atuin) and fish state
# (~/.local/share/fish) live under /home, which is a full persistent dataset, so
# they survive the ephemeral-root wipe — no extra persist entries needed.
{ ... }:
{
  programs.fish.enable = true;

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    # Local-only: no account, no server sync.
    settings = {
      auto_sync = false;
      update_check = false;
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };
}
