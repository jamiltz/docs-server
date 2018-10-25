#!/bin/bash

set -e

ROOT_CA=ca
INTERMEDIATE=int
NODE=pkey
CHAIN=chain
CLUSTER=${1:-172.23.123.176}
ip=${2:-127.0.0.1}
USERNAME=${2:-sdkqecertuser}
SSH_PASSWORD=${3:-couchbase}

ADMINCRED=Administrator:password

echo Generate ROOT CA
# Generate ROOT CA
openssl genrsa -out ${ROOT_CA}.key 2048 2>/dev/null
openssl req -new -x509  -days 3650 -sha256 -key ${ROOT_CA}.key -out ${ROOT_CA}.pem \
-subj '/C=UA/O=My Company/CN=My Company Root CA' 2>/dev/null

echo Generate Intermediate
# Generate intemediate key and sign with ROOT CA
openssl genrsa -out ${INTERMEDIATE}.key 2048 2>/dev/null
openssl req -new -key ${INTERMEDIATE}.key -out ${INTERMEDIATE}.csr -subj '/C=UA/O=My Company/CN=My Company Intermediate CA' 2>/dev/null
openssl x509 -req -in ${INTERMEDIATE}.csr -CA ${ROOT_CA}.pem -CAkey ${ROOT_CA}.key -CAcreateserial \
-CAserial rootCA.srl -extfile v3_ca.ext -out ${INTERMEDIATE}.pem -days 365 2>/dev/null

# Generate client key and sign with ROOT CA and INTERMEDIATE KEY
echo Generate RSA
openssl genrsa -out ${NODE}.key 2048 2>/dev/null
openssl req -new -key ${NODE}.key -out ${NODE}.csr -subj "/C=UA/O=My Company/CN=${USERNAME}" 2>/dev/null
openssl x509 -req -in ${NODE}.csr -CA ${INTERMEDIATE}.pem -CAkey ${INTERMEDIATE}.key -CAcreateserial \
-CAserial intermediateCA.srl -out ${NODE}.pem -days 365 -extfile openssl-san.cnf -extensions 'v3_req'

# Generate certificate chain file
cat ${NODE}.pem ${INTERMEDIATE}.pem ${ROOT_CA}.pem > ${CHAIN}.pem

# Install certificate to inbox
OS=${1:-centos} # or macos
if [ "${OS}" = "centos" ]; then
	echo Copying files to Ubuntu path
	INBOX=/opt/couchbase/var/lib/couchbase/inbox/
	mkdir ${INBOX}
	cp ./${CHAIN}.pem ${INBOX}${CHAIN}.pem
	chmod a+x ${INBOX}${CHAIN}.pem
	cp ./${NODE}.key ${INBOX}${NODE}.key
	chmod a+x ${INBOX}${NODE}.key
elif [ "${OS}" = "macos" ]; then
	echo Copying files to macOS path
	INBOX=/Users/jamesnocentini/Library/Application\ Support/Couchbase/var/lib/couchbase/inbox/
	mkdir ${INBOX}
	cp ./${CHAIN}.pem ${INBOX}${CHAIN}.pem
	chmod a+x ${INBOX}${CHAIN}.pem
	cp ./${NODE}.key ${INBOX}${NODE}.key
	chmod a+x ${INBOX}${NODE}.key
else
	echo "Error: the first param must be `ubuntu` or `macos`"
fi

# Upload ROOT CA and activate it
curl -s -o /dev/null --data-binary "@./${ROOT_CA}.pem" \
		http://${ADMINCRED}@${ip}:8091/controller/uploadClusterCA
curl -sX POST http://${ADMINCRED}@${ip}:8091/node/controller/reloadCertificate
# Enable client cert
POST_DATA='{"state": "enable","prefixes": [{"path": "subject.cn","prefix": "","delimiter": ""}]}'
curl -s -H "Content-Type: application/json" -X POST -d "${POST_DATA}" http://${ADMINCRED}@${ip}:8091/settings/clientCertAuth
