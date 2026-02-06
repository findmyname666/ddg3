{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      devshell,
      flake-utils,
      nixpkgs,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlays.default
            (import ./nix/overlays.nix)
          ];
        };
      in
      {
        devShell = pkgs.devshell.mkShell {
          packages = with pkgs; [
            azure-cli
            dbmate # DB migration tool
            gnumake
            go
            go_1_25
            golangci-lint
            golangci-lint
            gotools
            lychee
            markdownlint-cli
            pre-commit # Pre-commit tool for running pre-commit hooks
            shellcheck
            sqlc # Tool for generating Go code from SQL queries
            terraform # Terraform (custom build from overlay)
            tflint
            yamllint
          ];
        };
      }
    );
}
