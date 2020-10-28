let
  inherit (builtins) map filter listToAttrs attrValues isString currentSystem;
  inherit (import sources.dapptools {}) pkgs;
  inherit (pkgs) fetchgit;
  inherit (pkgs.lib.strings) removePrefix;

  getName = x:
   let
     parse = drv: (builtins.parseDrvName drv).name;
   in if isString x
      then parse x
      else x.pname or (parse x.name);

  sources = import ./sources.nix;
in

rec {
  nodepkgs = { pkgs ? pkgs, system ? currentSystem }: let
    nodepkgs' = import ./nodepkgs.nix { inherit pkgs system; };
    shortNames = listToAttrs (map
      (x: { name = removePrefix "node_" (getName x.name); value = x; })
      (attrValues nodepkgs')
    );
  in nodepkgs' // shortNames;
}
