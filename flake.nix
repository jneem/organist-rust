{
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.organist = {
    url = "github:nickel-lang/organist";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.fenix = {
    url = "github:nix-community/fenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-substituters = ["https://organist.cachix.org"];
    extra-trusted-public-keys = ["organist.cachix.org-1:GB9gOx3rbGl7YEh6DwOscD1+E/Gc5ZCnzqwObNH2Faw="];
  };

  outputs = {organist, ...} @ inputs:
    let system = "x86_64-linux"; in
    let organistOutputs = organist.flake.outputsFromNickel ./. inputs {}; in
    let pkgs = import inputs.nixpkgs { inherit system; }; in
    let targets = builtins.attrNames (pkgs.lib.attrsets.filterAttrs (n: v: builtins.isAttrs v) inputs.fenix.packages.${system}.targets); in
    organistOutputs //
    {
      packages.${system}.supportedTargets = pkgs.writeText "targets.ncl" ''
        {
        ${
          builtins.concatStringsSep ", \n" (builtins.map (t: "\"${t}\" | default = false") targets)
         }
        }
      '';
    };
}
