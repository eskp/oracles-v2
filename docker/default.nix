{ system ? builtins.currentSystem }:

let
  oracles = import ../. {};
  sources = import ../nix/sources.nix;
  inherit (import sources.dapptools {}) pkgs;
  inherit (import sources.nixpkgs { inherit system; }) dockerTools;

  setzer = pkgs.callPackage sources.setzer-mcd {};

  confer = prefix: out: ''
    set -eo pipefail

    query="."
    for confVar in ''${!${prefix}_SET_*}; do
      confPath="''${confVar#${prefix}_SET_}"
      confPath="''${confPath//__/[].}"
      confPath="''${confPath//_/.}"
      query+="
      | .$confPath = ''${!confVar}"
    done

    mkdir -p $(dirname "${out}")
    echo "''${${prefix}_SET:-''$(cat "''${${prefix}_CONFER_CONFIG:?Path to config not set}")}" \
      | { set -x; jq "$query" > "${out}"; }
    cat "${out}"
  '';

  omniaConfer = pkgs.writeShellScriptBin "omnia-confer"
    (confer "OMNIA" "/etc/omnia.conf");

  ssbConfer = pkgs.writeShellScriptBin "ssb-confer"
    (confer "SSB" "$HOME/.ssb/config");

  omniaRunner = pkgs.writeShellScriptBin "omnia-runner" ''
    set -eo pipefail

    for filePathVar in ''${!FILE_PATH_*}; do
      fileContentVar="FILE_CONT_''${filePathVar#FILE_PATH_}"
      filePath="''${!filePathVar}"
      echo "Creating file from ENV $fileContentVar -> $filePath"
      mkdir -p $(dirname "$filePath")
      echo -n "''${!fileContentVar}" > "$filePath"
    done

    set -x

    ssb-confer
    omnia-confer

    mkdir -p /var/logs

    ssb-server start 2>/var/logs/ssb-server.err >/var/logs/ssb-server.out &
    sleep 5

    test -z "$SSB_INVITE" || {
      ssb-server invite.accept "$SSB_INVITE"
      sleep 1
    }

    omnia 2>/var/logs/omnia.err >/var/logs/omnia.out &
    sleep 1

    tail -f /var/logs/*
    kill $$
  '';
in

rec {
  omniaBase = dockerTools.buildImage {
    name = "omnia-base";
    tag = "latest";

    contents = with pkgs; [
      tzdata coreutils jq
      oracles.ssb-server
      oracles.omnia
    ];

    config.Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];

    runAsRoot = ''
      mkdir -p /tmp
      for x in $(ls /lib/node_modules/.bin); do
        ln -sf /lib/node_modules/.bin/$x /bin
      done
    '';
  };

  omnia = dockerTools.buildImage {
    fromImage = omniaBase;
    name = "omnia";
    tag = "latest";

    contents = with pkgs; [
      ssbConfer
      omniaConfer
      omniaRunner
    ];

    config = {
      Env = [
        "SSB_CONFER_CONFIG=${../systemd/ssb-config.json}"
      ];
      Cmd = [ "/bin/omnia-runner" ];
      WorkingDir = "/";
    };
  };
}
