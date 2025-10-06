let
  # Pin nixpkgs to a specific release for reproducibility
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/840e8405978644a20844b54e70a09b518f5c7709.tar.gz";
    sha256 = "sha256:1k8p8hw8ldza4nh8rszyi4bpfmaac4qm00a3nc53hn5nps6z5n47";
  };

  pkgs = import nixpkgs { config.allowUnfree = true; };

  # Detect CI and CD from env variables
  isCI = builtins.getEnv "IS_CI" == "true";
  isCD = builtins.getEnv "IS_CD" == "true";
in
pkgs.mkShell {
  name = "secure-terraform-pipeline-shell";
  pure = true;

  buildInputs =
    if isCD then
      [ pkgs.terraform ]   # minimal for CD
    else if isCI then
      [ pkgs.go pkgs.checkov pkgs.conftest pkgs.terraform pkgs.terraform-local pkgs.awscli2 ]
    else
      [
        pkgs.git
        pkgs.awscli2
        pkgs.go
        pkgs.checkov
        pkgs.conftest
        pkgs.docker_28
        pkgs.terraform
        pkgs.terraform-local
        pkgs.act
      ];

  shellHook = ''
    export IS_CI="${if isCI then "true" else "false"}"
    export IS_CD="${if isCD then "true" else "false"}"
    export APP_ENV=development

    echo "======================================"
    if [ "$IS_CD" = "true" ]; then
      echo "Running in CD mode (only Terraform + AWS CLI installed)"
    elif [ "$IS_CI" = "true" ]; then
      echo "Running in CI mode (CI tools installed)"
    else
      echo "Running locally (all dev tools installed)"
    fi
    echo "======================================"

    echo "Checking tool versions..."
    terraform --version
    if [ "$IS_CD" != "true" ]; then
      go version
      checkov --version
      conftest --version
      git --version
      aws --version
      docker --version || echo "Docker not available or requires sudo"
      act --version
    fi
    echo "======================================"
  '';
}
