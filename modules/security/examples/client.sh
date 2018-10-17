#!/usr/bin/env bash

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

# Create keystore file and import ROOT/INTERMEDIATE/CLIENT cert
KEYSTORE_FILE=keystore.jks
STOREPASS=123456

cd ${TOPDIR}

keytool -genkey -keyalg RSA -alias selfsigned \
-keystore ${KEYSTORE_FILE} -storepass ${STOREPASS} -validity 360 -keysize 2048 \
-noprompt  -dname "CN=${USERNAME}, OU=None, O=None, L=None, S=None, C=US" -keypass ${STOREPASS}

keytool -certreq -alias selfsigned -keyalg RSA -file my.csr \
-keystore ${KEYSTORE_FILE} -storepass ${STOREPASS} -noprompt

openssl x509 -req -in my.csr -CA ./${INT_DIR}/${INTERMEDIATE}.pem \
-CAkey ./${INT_DIR}/${INTERMEDIATE}.key -CAcreateserial -out clientcert.pem -days 365

keytool -import -trustcacerts -file ./${ROOT_DIR}/${ROOT_CA}.pem \
-alias root -keystore ${KEYSTORE_FILE} -storepass ${STOREPASS} -noprompt

keytool -import -trustcacerts -file ./${INT_DIR}/${INTERMEDIATE}.pem \
-alias int -keystore ${KEYSTORE_FILE} -storepass ${STOREPASS} -noprompt

keytool -import -keystore ${KEYSTORE_FILE} -file clientcert.pem \
-alias selfsigned -storepass ${STOREPASS} -noprompt