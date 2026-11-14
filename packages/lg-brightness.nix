{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libusb1,
}:
rustPlatform.buildRustPackage {
  pname = "lg-brightness";
  version = "0.1.0-unstable-2026-09-30";

  src = fetchFromGitHub {
    owner = "ckunte";
    repo = "lg-brightness";
    rev = "a49b53250315081998ea490d57d47d3a5cb64594";
    hash = "sha256-Ziz1IWpd302k5/zTAyN6UemqNJxJncMw6kG5o+R1bTY=";
  };
  cargoHash = "sha256-KcBAqhYGCfgGdBX/57bICy8PFDy4S5NOTbZvvqt+IaY=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libusb1 ];

  postInstall = ''
    mkdir -p $out/lib/udev/rules.d
    cat > $out/lib/udev/rules.d/70-lg-ultrafine.rules <<'EOF'
    ACTION!="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="043e", ATTR{idProduct}=="9a40|9a63|9a70", TAG+="uaccess"
    EOF
  '';

  meta = {
    description = "USB brightness control for LG UltraFine displays";
    homepage = "https://github.com/ckunte/lg-brightness";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "lg-brightness";
  };
}
