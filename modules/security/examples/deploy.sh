#!/usr/bin/env bash

set -e
CLUSTER=${1:-172.23.123.176}
SSH_PASSWORD=${2:-couchbase}
INBOX=${3:-/opt/couchbase/var/lib/couchbase/inbox/}
# -> for macOS: /Applications/Couchbase\ Server\ 5.5.1.app/Contents/Resources/couchbase-core/var/lib/couchbase/inbox/

export TOPDIR=SSLCA
export ROOT_DIR=rootdir
export NODE_DIR=nodedir
export INT_DIR=intdir

export ROOT_CA=ca
export INTERMEDIATE=int
export NODE=pkey
export CHAIN=chain

export ADMINCRED=Administrator:password

CHAIN=chain
NODE=pkey
SSH="sshpass -p $SSH_PASSWORD ssh -o StrictHostKeyChecking=no"
SCP="sshpass -p $SSH_PASSWORD scp -o StrictHostKeyChecking=no"

cd ${TOPDIR}

${SSH} root@${CLUSTER} "mkdir ${INBOX}" 2>/dev/null || true
${SCP} ${CHAIN}.pem root@${CLUSTER}:${INBOX}
${SCP} ${NODE_DIR}/${NODE}.key root@${CLUSTER}:${INBOX}
${SSH} root@${CLUSTER} "chmod a+x ${INBOX}${CHAIN}"
${SSH} root@${CLUSTER} "chmod a+x ${INBOX}${NODE}.key"

curl -X POST --data-binary "@./${ROOT_DIR}/${ROOT_CA}.pem" \
http://${ADMINCRED}@${CLUSTER}:8091/controller/uploadClusterCA
curl -X POST http://${ADMINCRED}@${CLUSTER}:8091/node/controller/reloadCertificate

# Before the quickfix
function helloWorld
    { if echo Hello; then echo " World"; fi }