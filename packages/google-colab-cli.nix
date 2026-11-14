{
  lib,
  openssh,
  python3Packages,
}:
let
  jupyter-mimetypes = python3Packages.buildPythonPackage rec {
    pname = "jupyter-mimetypes";
    version = "0.2.0";
    format = "wheel";

    src = python3Packages.fetchPypi {
      pname = "jupyter_mimetypes";
      inherit version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-5tzZiSWOP8lENltlbZFzGRUX4OOTvYeOl85QDls4hSc=";
    };

    dependencies = with python3Packages; [
      pyarrow
      typing-extensions
    ];

    pythonImportsCheck = [ "jupyter_mimetypes" ];

    meta = {
      homepage = "https://github.com/datalayer/jupyter-mimetypes";
      license = lib.licenses.bsd3;
    };
  };

  jupyter-kernel-client = python3Packages.buildPythonPackage rec {
    pname = "jupyter-kernel-client";
    version = "0.9.0";
    format = "wheel";

    src = python3Packages.fetchPypi {
      pname = "jupyter_kernel_client";
      inherit version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-d6y48vc42XYl1r0B7ozyHE1ZeQt7pGQQhxLbOHBBbyA=";
    };

    dependencies = with python3Packages; [
      jupyter-client
      jupyter-core
      jupyter-mimetypes
      requests
      traitlets
      typing-extensions
      websocket-client
    ];

    pythonImportsCheck = [ "jupyter_kernel_client" ];

    meta = {
      homepage = "https://github.com/datalayer/jupyter-kernel-client";
      license = lib.licenses.bsd3;
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "google-colab-cli";
  version = "0.8.0";
  pyproject = true;
  disabled = python3Packages.python.pythonOlder "3.12";

  src = python3Packages.fetchPypi {
    pname = "google_colab_cli";
    inherit version;
    hash = "sha256-fLVoaI6LzeFOi03SFBy9dtjZZTqVbcr307ea22vr7V0=";
  };

  build-system = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  dependencies = with python3Packages; [
    click
    filelock
    google-auth
    google-auth-oauthlib
    html2text
    jupyter-kernel-client
    keyring
    nbformat
    packaging
    prompt-toolkit
    pydantic
    pygments
    requests
    rich
    typer
    typing-extensions
    websocket-client
  ];

  # A bare `python -m colab_cli.cli` loses the entry point's Nix sys.path.
  # Re-enter the installed wrapper when OpenSSH launches the proxy instead.
  postPatch = ''
    substituteInPlace src/colab_cli/commands/ssh.py tests/test_ssh.py tests/test_ssh_cmd.py \
      --replace-fail 'sys.executable, "-m", "colab_cli.cli"' "\"$out/bin/colab\""
    substituteInPlace tests/test_ssh.py \
      --replace-fail $'        sys.executable,\n        "-m",\n        "colab_cli.cli",' "        \"$out/bin/colab\"," \
      --replace-fail 'argv[:7]' 'argv[:5]' \
      --replace-fail 'argv[7:]' 'argv[5:]'
  '';

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ openssh ])
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-mock
  ];

  preCheck = ''
    export HOME="$TMPDIR"
  '';

  pythonImportsCheck = [ "colab_cli.cli" ];

  # Exercise the installed CLI and SSH proxy without credentials or a runtime.
  doInstallCheck = true;
  postInstallCheck = ''
    export HOME="$TMPDIR"
    "$out/bin/colab" version | grep -F 'Version: ${version}'
    "$out/bin/colab" --help > /dev/null
    "$out/bin/colab" readme > /dev/null
    "$out/bin/colab" skill > /dev/null
    ${python3Packages.python.interpreter} - <<'PY'
    import os
    import runpy
    import shlex
    import subprocess
    from types import SimpleNamespace

    # Load the installed entry point's paths, without invoking its main().
    out = os.environ["out"]
    runpy.run_path(f"{out}/bin/.colab-wrapped", run_name="colab_packaging_check")
    from colab_cli.commands.ssh import _proxy_command

    command = shlex.split(_proxy_command(SimpleNamespace(name="session with spaces"), None, "interactive"))
    env = {k: v for k, v in os.environ.items() if k not in ("PYTHONPATH", "NIX_PYTHONPATH")}
    env["PATH"] = ""
    subprocess.run(command + ["--help"], env=env, check=True, stdout=subprocess.DEVNULL)
    PY
  '';

  meta = {
    description = "CLI for interacting with Google Colab runtimes";
    homepage = "https://github.com/googlecolab/google-colab-cli";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    mainProgram = "colab";
  };
}
