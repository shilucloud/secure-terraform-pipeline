let
  # Pin nixpkgs to a specific release for reproducibility
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/840e8405978644a20844b54e70a09b518f5c7709.tar.gz";
    sha256 = "sha256:1k8p8hw8ldza4nh8rszyi4bpfmaac4qm00a3nc53hn5nps6z5n47";
  };

  pkgs = import nixpkgs { config.allowUnfree = true; };

  # Detect CI and CD from env variables
  isCI = builtins.getEnv "WORKFLOW" == "ci";
  isCD = builtins.getEnv "WORKFLOW" == "cd";
  isDriftCtl = builtins.getEnv "WORKFLOW" == "driftctl";
in
pkgs.mkShell {
  name = "secure-terraform-pipeline-shell";
  pure = true;

  buildInputs =
    if isCD then
      [ pkgs.terraform ] 
    else if isDriftCtl then 
      [ pkgs.driftctl pkgs.terraform ]
    else if isCI then
      [ pkgs.go pkgs.checkov pkgs.conftest pkgs.terraform pkgs.terraform-local pkgs.awscli2 pkgs.tflint ]
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
        pkgs.driftctl
        pkgs.tflint
      ];

  shellHook = ''
    export IS_CI="${if isCI then "true" else "false"}"
    export IS_CD="${if isCD then "true" else "false"}"
    export IS_DRIFTCTL="${if isDriftCtl then "true" else "false"}"
    export APP_ENV=development

    echo "======================================"
    if [ "$IS_CD" = "true" ]; then
      echo "Running in CD mode (only Terraform )"
    elif [ "$IS_CI" = "true" ]; then
      echo "Running in CI mode (CI tools installed)"
    elif [ "$IS_DRIFTCTL" = "true" ]; then 
      echo "Running in DriftCTL mode (terraform and checkov)"
    else
      echo "Running locally (all dev tools installed)"
    fi
    echo "======================================"

    echo "Checking tool versions..."
    terraform --version
    if [ "$IS_CI" == "true" ]; then
      go version
      checkov --version
      conftest --version
      git --version
      aws --version
      docker --version || echo "Docker not available or requires sudo"
      act --version

    elif [ "$IS_DRIFTCTL" == "true" ]; then
      driftctl version 

    elif [ "$IS_CD" == "true" ]; then
      echo "===================================="
    else 
      go version
      checkov --version
      conftest --version
      git --version
      aws --version
      docker --version || echo "Docker not available or requires sudo"
      act --version
      driftctl version
    fi 
    echo "======================================="
  '';
}