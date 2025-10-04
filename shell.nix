let
  # Pin nixpkgs to a specific release for reproducibility
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/840e8405978644a20844b54e70a09b518f5c7709.tar.gz";
    sha256 = "sha256:1k8p8hw8ldza4nh8rszyi4bpfmaac4qm00a3nc53hn5nps6z5n47";
  };

  pkgs = import nixpkgs { config.allowUnfree = true; };

  # Detect CI from env variable
  isCI = builtins.getEnv "IS_CI" == "true";
in
pkgs.mkShell {
  name = "secure-terraform-pipeline-shell";
  pure = true;

  buildInputs = if isCI then
    [ pkgs.go pkgs.checkov pkgs.conftest pkgs.terraform pkgs.terraform-local]
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
      pkgs.terraform-local
    ];

  shellHook = ''
  export IS_CI="${if isCI then "true" else "false"}"
  
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