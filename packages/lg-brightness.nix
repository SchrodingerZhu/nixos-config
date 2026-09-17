{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libusb1,
}:
rustPlatform.buildRustPackage {
  pname = "lg-brightness";
  version = "0.1.0-unstable-2026-07-10";

  src = fetchFromGitHub {
    owner = "ckunte";
    repo = "lg-brightness";
    rev = "6a33e6663e4981038631219e75a65eb5bb37b75d";
    hash = "sha256-aWvHzBkpbnKHgSmdp265l2c/O1rQYtorxQmHyuYPS0U=";
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
