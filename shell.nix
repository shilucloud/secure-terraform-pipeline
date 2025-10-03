let
  # Pin nixpkgs to a specific release for reproducibility
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-25.05.tar.gz";
    sha256 = "sha256:0pcnq88aj9zvln1ma1pp244z08cvdshvfb6w92pk5xgglpb4900l";
  };

  pkgs = import nixpkgs { config.allowUnfree = true; };

  # Detect CI from env variable
  isCI = builtins.getEnv "IS_CI" == "true";
in
pkgs.mkShell {
  name = "secure-terraform-pipeline-shell";
  pure = true;

  buildInputs = if isCI then
    [ pkgs.go pkgs.checkov pkgs.conftest pkgs.terraform ]
  else
    [
      pkgs.git
      pkgs.awscli2
      pkgs.go
      pkgs.checkov
      pkgs.conftest
      pkgs.docker_28
      pkgs.terraform
      pkgs.act
    ];

  shellHook = ''
    echo "======================================"
    echo "Pinned nixpkgs dev shell loaded!"
    export APP_ENV=development

    if [ "$IS_CI" = "true" ]; then
      echo "Running in CI mode (only go, checkov, conftest, terraform included)"
    else
      echo "Running locally (all dev tools included)"
    fi

    echo "======================================"
    echo "Checking tool versions..."
    go version
    checkov --version
    conftest --version
    terraform --version

    if [ "$IS_CI" != "true" ]; then
      git --version
      aws --version
      docker --version || echo "Docker not available or requires sudo"
      act --version
    fi
    echo "======================================"
  '';
}
