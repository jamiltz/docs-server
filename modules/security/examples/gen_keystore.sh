#!/usr/bin/env bash

set -e

export TOPDIR=SSLCA
export ROOT_DIR=rootdir
export NODE_DIR=nodedir
export INT_DIR=intdir

export ROOT_CA=ca
export INTERMEDIATE=int
export NODE=pkey
export CHAIN=chain

export ADMINCRED=Administrator:password
export ip=127.0.0.1
export USERNAME=travel-sample

mkdir ${TOPDIR}
cd ${TOPDIR}
mkdir ${ROOT_DIR}
mkdir ${INT_DIR}
mkdir ${NODE_DIR}

cd ${ROOT_DIR}
openssl genrsa -out ${ROOT_CA}.key 2048
openssl req -new -x509 -days 3650 -sha256 -key ${ROOT_CA}.key \
-out ${ROOT_CA}.pem -subj '/C=UA/O=MyCompany/CN=MyCompanyRootCA'

cd ../${INT_DIR}
openssl genrsa -out ${INTERMEDIATE}.key 2048
openssl req -new -key ${INTERMEDIATE}.key -out ${INTERMEDIATE}.csr \
-subj '/C=UA/O=MyCompany/CN=MyCompanyIntermediateCA'

cat <<EOF>> ./v3_ca.ext
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
basicConstraints = CA:true
EOF

openssl x509 -req -in ${INTERMEDIATE}.csr \
-CA ../${ROOT_DIR}/${ROOT_CA}.pem -CAkey ../${ROOT_DIR}/${ROOT_CA}.key \
-CAcreateserial -CAserial ../${ROOT_DIR}/rootCA.srl -extfile ./v3_ca.ext \
-out ${INTERMEDIATE}.pem -days 365

cd ../${NODE_DIR}
openssl genrsa -out ${NODE}.key 2048
openssl req -new -key ${NODE}.key -out ${NODE}.csr \
-subj "/C=UA/O=MyCompany/CN=${USERNAME}"
openssl x509 -req -in ${NODE}.csr -CA ../${INT_DIR}/${INTERMEDIATE}.pem \
-CAkey ../${INT_DIR}/${INTERMEDIATE}.key -CAcreateserial \
-CAserial ../${INT_DIR}/intermediateCA.srl -out ${NODE}.pem -days 365

cd ..
cat ./${NODE_DIR}/${NODE}.pem ./${INT_DIR}/${INTERMEDIATE}.pem > ${CHAIN}.pem

OS=${1:-ubuntu} # or macos
if [ "${OS}" = "ubuntu" ]; then
	echo Copying files to Ubuntu path
	mkdir /opt/couchbase/var/lib/couchbase/inbox/
	cp ./${CHAIN}.pem /opt/couchbase/var/lib/couchbase/inbox/${CHAIN}.pem
	chmod a+x /opt/couchbase/var/lib/couchbase/inbox/${CHAIN}.pem
	cp ./${NODE_DIR}/${NODE}.key /opt/couchbase/var/lib/couchbase/inbox/${NODE}.key
	chmod a+x /opt/couchbase/var/lib/couchbase/inbox/${NODE}.key
elif [ "${OS}" = "macos" ]; then
	echo Copying files to macOS path
	mkdir /Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/var/lib/couchbase/inbox/
	cp ./${CHAIN}.pem /Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/var/lib/couchbase/inbox/${CHAIN}.pem
	chmod a+x /Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/var/lib/couchbase/inbox/${CHAIN}.pem
	cp ./${NODE_DIR}/${NODE}.key /Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/var/lib/couchbase/inbox/${NODE}.key
	chmod a+x /Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/var/lib/couchbase/inbox/${NODE}.key
else
	echo "Error: the first param must be `ubuntu` or `macos`"
fi

curl -X POST --data-binary "@./${ROOT_DIR}/${ROOT_CA}.pem" \
http://${ADMINCRED}@${ip}:8091/controller/uploadClusterCA
curl -X POST http://${ADMINCRED}@${ip}:8091/node/controller/reloadCertificate


curl -u ${ADMINCRED} -v -X POST http://${ip}:8091/settings/clientCertAuth \
-d '{"state": "enable","prefixes": [{"path": "subject.cn","prefix": "","delimiter": ""}]}'

