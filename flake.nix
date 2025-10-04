# flake.nix
{
  description = "Dev shell for secure-terraform-pipeline";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/0d28a19b3a63964649a2ef72ef11a8707d212ff8"; # pinned commit
  };

  outputs = { self, nixpkgs }: {
    devShells.default = nixpkgs.lib.mkShell {
      buildInputs = [
        nixpkgs.git
        nixpkgs.awscli2
        nixpkgs.go
        nixpkgs.terraform
        nixpkgs.terraform-local
        nixpkgs.checkov
        nixpkgs.conftest
        nixpkgs.docker
      ];

      shellHook = ''
        echo "Pinned flake dev shell loaded!"
        export APP_ENV=development
        go version
        terraform --version
        aws --version
      '';
    };
  };
}
