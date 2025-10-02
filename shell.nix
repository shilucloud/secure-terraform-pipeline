let
  # Pin nixpkgs to a specific release for reproducibility
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-25.05.tar.gz";
    sha256 = "sha256-0pcnq88aj9zvln1ma1pp244z08cvdshvfb6w92pk5xgglpb4900l";
  };

  pkgs = import nixpkgs {};
in
pkgs.mkShell {
  name = "secure-terraform-pipeline-shell";
  pure = true; # Optional: ensures a clean environment without host leaks

  buildInputs = [
    pkgs.git
    pkgs.awscli2
    pkgs.go
    pkgs.checkov
    pkgs.conftest
    pkgs.docker_28
    pkgs.terraform
  ];

  shellHook = ''
    echo "======================================"
    echo "Pinned nixpkgs dev shell loaded!"
    export APP_ENV=development
    echo "======================================"
    echo "Checking tool versions..."
    go version
    aws --version
    git --version
    checkov --version
    docker --version || echo "Docker not available or requires sudo"
    terraform --version
    echo "======================================"
  '';
}
