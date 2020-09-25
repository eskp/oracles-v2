#!/usr/bin/env bash

set -o errexit

HOME=/home/omnia

mkdir -p $HOME/secrets
[[ -z "$OMNIA_CAPS" ]] && echo "OMNIA_CAPS not set" || echo -e $OMNIA_CAPS > $HOME/secrets/caps.json
[[ -z "$OMNIA_KEYSTORE" ]] && echo "OMNIA_KEYSTORE not set" || echo $OMNIA_KEYSTORE > $HOME/secrets/keystore.json
[[ -z "$OMNIA_PASSWORD" ]] && echo "OMNIA_PASSWORD not set" || echo $OMNIA_PASSWORD > $HOME/secrets/password.txt

sudo -E \
    $HOME/.nix-profile/bin/install-omnia feed \
        --ssb-external $EXT_IP \
        --from $ETH_FROM \
        --ssb-caps $HOME/secrets/caps.json \
        --keystore $HOME/secrets \
        --password $HOME/secrets/password.txt

sudo chown -R omnia $HOME/.ssb/

echo ##################
echo "OMNIA CONFIG"
echo ##################
cat /etc/omnia.conf
echo ##################
echo "ENV VARS"
echo ##################
env
echo ##################
echo "SSB CONFIG"
echo ##################
cat $HOME/.ssb/config

/home/omnia/.nix-profile/bin/ssb-server start &

sleep 10

/home/omnia/.nix-profile/bin/ssb-server invite.accept $SSB_INVITE

sudo -E -iu omnia omnia
