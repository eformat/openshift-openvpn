#!/bin/bash

# TODO: Let user supply their own CA and Server certs instead
#       of using the autogenerated ones from the Docker image
# TODO: user/pass is hardcoded to foo/bar in verify_user_pass.sh
# TODO: 10.2.3.0 network is hardcoded

VERB=1

if [ "$DEBUG" == "true" ]; then
    set -x
    VERB=4
fi

set -e

KEY_DIR=${OPENVPN_DIR}/easy-rsa/keys
CA_CRT=${KEY_DIR}/ca.crt

# Moved to Dockerfile to run when image gets built for now
# if [ ! -f $CA_CRT ]; then
#     pushd ${OPENVPN_DIR}/easy-rsa
#     . ./vars
#     ./clean-all
#     ./pkitool --batch --initca
#     ./pkitool --batch --server server
#     ./build-dh
#     popd
# fi

echo -e "\n\nSave this CA certificate to a file for use in your VPN client\n"
cat $CA_CRT

KUBE_SERVICE_NETWORK=`echo $KUBERNETES_SERVICE_HOST | awk -F . '{print $1"."$2".0.0"}'`
SEARCH_DOMAINS=`grep search /etc/resolv.conf | xargs -n 1 | grep -v "^search$" | xargs -n 1 -I '{}' echo '--push dhcp-option DOMAIN {}'`
DNS_SERVER=`grep nameserver /etc/resolv.conf | head -n 1 | xargs -n 1 | grep -v "^nameserver$"`
DNS_SERVER_NETWORK=`echo $DNS_SERVER | awk -F . '{print $1"."$2"."$3".0"}'`

openvpn --dev tun0 \
        --persist-tun \
        --script-security 3 \
        --verb $VERB \
        --client-connect ${OPENVPN_DIR}/client_command.sh \
        --client-disconnect ${OPENVPN_DIR}/client_command.sh \
        --up ${OPENVPN_DIR}/updown.sh \
        --down ${OPENVPN_DIR}/updown.sh \
        --dh ${KEY_DIR}/dh2048.pem \
        --ca $CA_CRT \
        --cert ${KEY_DIR}/server.crt \
        --key ${KEY_DIR}/server.key \
        --client-cert-not-required \
        --auth-user-pass-verify ${OPENVPN_DIR}/verify_user_pass.sh via-env \
        --server 10.2.3.0 255.255.255.0 \
        --proto tcp-server \
        --topology subnet \
        --keepalive 10 60 \
        --push "route $KUBE_SERVICE_NETWORK 255.255.0.0" \
        --push "route $DNS_SERVER_NETWORK 255.255.255.0" \
        --push "dhcp-option DNS $DNS_SERVER" \
        $SEARCH_DOMAINS