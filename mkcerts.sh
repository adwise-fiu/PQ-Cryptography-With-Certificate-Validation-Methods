#!/bin/bash

# Script to:
# 1. Create various Root CA, Intermediate CA, OCSP signing, Web Server, & Web Client certificates
#	included signature algorithms: RSA, ECDSA, EdDSA, Falcon512 & 1024, Dilithium 2, 3 & 5, SPHINCS+-SHAKE256, SPHINCS+-SHA-256, SPHINCS+-Haraka

# Requires OQS OpenSSL installed

BASE_DIR=$(pwd)

###############################################################################
################################## IMPORTANT ##################################
###############################################################################
# The variables in this section MUST be set for proper execution of this script.

# You may also need to edit the openssl.cnf file included in this repo to set
# the OCSP URL. Look for the lines that say:

# ---------------EDIT BELOW WITH YOUR DESIRED OCSP SERVER URL
# authorityInfoAccess    = OCSP;URI:http://ocsp:8080	

# under the relevant x509 extension headers section. 

#ABSOLUTE path to the OQS OpenSSL executable:
qopenssl=$BASE_DIR/openssl/apps/openssl

#ABSOLUTE path to openssl config file (openssl.cnf):
conffile=$BASE_DIR/openssl.cnf
#You will have to change a lot in this script f you don't use the config file included with this repo

#Algorithms to generate certs with:
ALGS=("rsa" "ecdsa" "eddsa" "falcon512" "falcon1024" "dilithium2" "dilithium3" "dilithium5" "sphincsharaka128fsimple" "sphincssha256128ssimple" "sphincsshake256128fsimple" "p256_dilithium2" "p256_falcon512" "p256_sphincssha256128ssimple")
# rsa, ecdsa, & eddsa are specially coded - for PQ algorithms, make sure the name matches exactly with what is listed by liboqs, and it should work if OpenSSL has been compiled with support for those algorithms

#--------------------------- CERTIFICATE SUBJECT DN ---------------------------
declare -A subject
declare -A CN
declare -A pass
# ------------ Customize below at will ------------
# ------ Individual Params ------
#Country Name  (2 letter code):
C="US"
#State or Province Name (full name):
ST="Maryland"
#Locality Name (eg. City):
L="Baltimore"
#Organization Name (company):
O="Internet Widgits Pty Ltd"
#Organizational Unit Name (eg. section):
OU="Server Research Department"
#e-mail address:
emailAddress="test@example.com"

#Common Names (eg. Server FQDN):
CN[root]="Root_CA"
CN[inter]="Intermediate_CA"
CN[ocsp]="OCSP"
CN[svr]="Server"
CN[usr]="User"

# -------- Complete DN ----------
subject[root]="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=${CN[root]}/emailAddress=$emailAddress"
subject[inter]="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=${CN[inter]}/emailAddress=$emailAddress"
subject[ocsp]="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=${CN[ocsp]}/emailAddress=$emailAddress"
subject[svr]="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=${CN[svr]}/emailAddress=$emailAddress"
subject[usr]="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=${CN[usr]}/emailAddress=$emailAddress"

#Private Key Passphrases:
#By default, the root key passphrase is used for all
pass[root]="abc123"
pass[inter]=${pass[root]}
pass[ocsp]=${pass[root]}
pass[svr]=${pass[root]}
pass[usr]=${pass[root]}
#------------------------------------------------------------------------------
###############################################################################


# -----------------------------------------------------------------------------
# logging helpers
# -----------------------------------------------------------------------------

function _log {
	level=$1
	msg=$2

	case "$level" in
		info)
			tag="\e[1;36minfo\e[0m"
			;;
		err)
			tag="\e[1;31merr \e[0m"
			;;
		warn)
			tag="\e[1;33mwarn\e[0m"
			;;
		ok)
			tag="\e[1;32m ok \e[0m"
			;;
		fail)
			tag="\e[1;31mfail\e[0m"
			;;
		*)
			tag="	"
			;;
	esac
	echo -e "`date +%Y-%m-%dT%H:%M:%S` [$tag] $msg"
}

function _err {
	msg=$1
	_log "err" "$msg"
}

function _warn {
	msg=$1
	_log "warn" "$msg"
}

function _info {
	msg=$1
	_log "info" "$msg"
}

function _success {
	msg=$1
	_log "ok" "$msg"
}

function _fail {
	msg=$1
	_log "fail" "$msg"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

haserr=0
for ALG in ${ALGS[@]}; do
	_info "================== $ALG =================="
	#Directory buildout
	mkdir -p $BASE_DIR/certs/$ALG && cd $BASE_DIR/certs/$ALG	
	mkdir -p {root/newcerts,inter/newcerts}
	touch root/index.txt && touch inter/index.txt
	echo 01 > root/serial && echo 01 > inter/serial

	#ROOT CA
	_info "Generating Root CA cert..."
	if [ $ALG == "rsa" ]; then
		$qopenssl req -x509 -config $conffile -newkey rsa:4096 -sha256 -subj "${subject[root]}" -out root/cacert.pem -passout pass:"${pass[root]}" -keyout root/cakey.pem -extensions v3_rca -days 730 -batch;
	elif [ $ALG == "ecdsa" ]; then
		$qopenssl ecparam -name prime256v1 -genkey -out root/cakey.pem;				#Generate EC private key
		$qopenssl ec -in root/cakey.pem -out root/cakey.pem -aes256 -passout pass:"${pass[root]}";		#Encrypt it
		$qopenssl req -x509 -config $conffile -key root/cakey.pem -passin pass:"${pass[root]}" -sha256 -out root/cacert.pem -subj "${subject[root]}" -extensions v3_rca -days 730 -batch;
	elif [ $ALG == "eddsa" ]; then
		$qopenssl genpkey -algorithm ED25519 -out root/cakey.pem -pass pass:"${pass[root]}";		#Generate ED25519 encrypted private key
		$qopenssl req -x509 -config $conffile -key root/cakey.pem -passin pass:"${pass[root]}" -sha256 -out root/cacert.pem -subj "${subject[root]}" -extensions v3_rca -days 730 -batch;
	else
		$qopenssl req -x509 -config $conffile -newkey $ALG -sha256 -subj "${subject[root]}" -out root/cacert.pem -passout pass:"${pass[root]}" -keyout root/cakey.pem -extensions v3_rca -days 730 -batch;
	fi
	#$qopenssl x509 -purpose -in root/cacert.pem ;
	if [ $? -eq 0 ]; then
		_success "Root CA cert/key generated"
	else
		haserr=1
		_err "Error"
	fi

	#INTERMEDIATE CA
	_info "Generating Intermediate CA cert..."
	if [ $ALG == "rsa" ]; then
		$qopenssl req -new -config $conffile -newkey rsa:4096 -sha256 -subj "${subject[inter]}" -out inter/cacert.csr -passout pass:"${pass[inter]}" -keyout inter/cakey.pem -batch;
	elif [ $ALG == "ecdsa" ]; then
		$qopenssl ecparam -name prime256v1 -genkey -out inter/cakey.pem;				#Generate EC private key
		$qopenssl ec -in inter/cakey.pem -out inter/cakey.pem -aes256 -passout pass:"${pass[inter]}";	#Encrypt it
		$qopenssl req -new -config $conffile -key inter/cakey.pem -passin pass:"${pass[inter]}" -sha256 -out inter/cacert.csr -subj "${subject[inter]}" -batch;
	elif [ $ALG == "eddsa" ]; then
		$qopenssl genpkey -algorithm ED25519 -out inter/cakey.pem -pass pass:"${pass[inter]}";		#Generate ED25519 encrypted private key
		$qopenssl req -new -config $conffile -key inter/cakey.pem -passin pass:"${pass[inter]}" -sha256 -out inter/cacert.csr -subj "${subject[inter]}" -batch;
	else
		$qopenssl req -new -config $conffile -newkey $ALG -sha256 -subj "${subject[inter]}" -out inter/cacert.csr -passout pass:"${pass[inter]}" -keyout inter/cakey.pem -batch;
	fi
	#$qopenssl req -text -noout -verify -in inter/cacert.csr -config $conffile;
	$qopenssl ca -config $conffile -cert root/cacert.pem -keyfile root/cakey.pem -passin pass:"${pass[root]}" -extensions v3_ica -out inter/cacert.pem -batch -days 365 -infiles inter/cacert.csr;
	#$qopenssl x509 -purpose -in inter/cacert.pem ;
	$qopenssl verify -verbose -CAfile root/cacert.pem inter/cacert.pem;
	if [ $? -eq 0 ]; then
		_success "Intermediate CA cert/key generated"
	else
		haserr=1
		_err "Error"
	fi

	#OCSP
	_info "Generating OCSP signing cert..."
	if [ $ALG == "rsa" ]; then
		$qopenssl req -new -config $conffile -newkey rsa:4096 -sha256 -subj "${subject[ocsp]}" -out ocspcert.csr -passout pass:"${pass[ocsp]}" -keyout ocspkey.pem -batch;
	elif [ $ALG == "ecdsa" ]; then
		$qopenssl ecparam -name prime256v1 -genkey -out ocspkey.pem;			#Generate EC private key
		$qopenssl ec -in ocspkey.pem -out ocspkey.pem -aes256 -passout pass:"${pass[ocsp]}";	#Encrypt it
		$qopenssl req -new -config $conffile -key ocspkey.pem -passin pass:"${pass[ocsp]}" -sha256 -out ocspcert.csr -subj "${subject[ocsp]}" -batch;
	elif [ $ALG == "eddsa" ]; then
		$qopenssl genpkey -algorithm ED25519 -out ocspkey.pem -pass pass:"${pass[ocsp]}";		#Generate ED25519 encrypted private key
		$qopenssl req -new -config $conffile -key ocspkey.pem -passin pass:"${pass[ocsp]}" -sha256 -out ocspcert.csr -subj "${subject[ocsp]}" -batch;
	else
		$qopenssl req -new -config $conffile -newkey $ALG -sha256 -subj "${subject[ocsp]}" -out ocspcert.csr -passout pass:"${pass[ocsp]}" -keyout ocspkey.pem -batch;
	fi
	#$qopenssl req -text -noout -verify -in ocspcert.csr -config $conffile;
	$qopenssl ca -config $conffile -name InterCA -cert inter/cacert.pem -keyfile inter/cakey.pem -passin pass:"${pass[inter]}" -extensions v3_ocsp -out ocspcert.pem -batch -days 365 -infiles ocspcert.csr;
	#$qopenssl x509 -purpose -in ocspcert.pem ;
	$qopenssl verify -verbose -CAfile root/cacert.pem -untrusted inter/cacert.pem ocspcert.pem;
	if [ $? -eq 0 ]; then
		_success "OCSP cert/key generated"
	else
		haserr=1
		_err "Error"
	fi

	#HTTPS SVR
	_info "Generating HTTPS Server cert..."
	if [ $ALG == "rsa" ]; then
		$qopenssl req -new -config $conffile -newkey rsa:4096 -sha256 -subj "${subject[svr]}" -out svrcert.csr -passout pass:"${pass[svr]}" -keyout svrkey.pem -batch;
	elif [ $ALG == "ecdsa" ]; then
		$qopenssl ecparam -name prime256v1 -genkey -out svrkey.pem;				#Generate EC private key
		$qopenssl ec -in svrkey.pem -out svrkey.pem -aes256 -passout pass:"${pass[svr]}";		#Encrypt it
		$qopenssl req -new -config $conffile -key svrkey.pem -passin pass:"${pass[svr]}" -sha256 -out svrcert.csr -subj "${subject[svr]}" -batch;
	elif [ $ALG == "eddsa" ]; then
		$qopenssl genpkey -algorithm ED25519 -out svrkey.pem -pass pass:"${pass[svr]}";		#Generate ED25519 encrypted private key
		$qopenssl req -new -config $conffile -key svrkey.pem -passin pass:"${pass[svr]}" -sha256 -out svrcert.csr -subj "${subject[svr]}" -batch;
	else
		$qopenssl req -new -config $conffile -newkey $ALG -sha256 -subj "${subject[svr]}" -out svrcert.csr -passout pass:"${pass[svr]}" -keyout svrkey.pem -batch;
	fi
	#$qopenssl req -text -noout -verify -in svrcert.csr -config $conffile;
	$qopenssl ca -config $conffile -name InterCA -cert inter/cacert.pem -keyfile inter/cakey.pem -passin pass:"${pass[inter]}" -extensions v3_server -out svrcert.pem -batch -days 365 -infiles svrcert.csr;
	#$qopenssl x509 -purpose -in svrcert.pem ;
	$qopenssl verify -verbose -CAfile root/cacert.pem -untrusted inter/cacert.pem svrcert.pem;
	if [ $? -eq 0 ]; then
		_success "Server cert/key generated"
	else
		haserr=1
		_err "Error"
	fi

	#HTTPS CLIENT
	_info "Generating HTTPS Client cert..."
	if [ $ALG == "rsa" ]; then
		$qopenssl req -new -config $conffile -newkey rsa:4096 -sha256 -subj "${subject[usr]}" -out usrcert.csr -passout pass:"${pass[usr]}" -keyout usrkey.pem -batch;
	elif [ $ALG == "ecdsa" ]; then
		$qopenssl ecparam -name prime256v1 -genkey -out usrkey.pem;				#Generate EC private key
		$qopenssl ec -in usrkey.pem -out usrkey.pem -aes256 -passout pass:"${pass[usr]}";		#Encrypt it
		$qopenssl req -new -config $conffile -key usrkey.pem -passin pass:"${pass[usr]}" -sha256 -out usrcert.csr -subj "${subject[usr]}" -batch;
	elif [ $ALG == "eddsa" ]; then
		$qopenssl genpkey -algorithm ED25519 -out usrkey.pem -pass pass:"${pass[usr]}";		#Generate ED25519 encrypted private key
		$qopenssl req -new -config $conffile -key usrkey.pem -passin pass:"${pass[usr]}" -sha256 -out usrcert.csr -subj "${subject[usr]}" -batch;
	else
		$qopenssl req -new -config $conffile -newkey $ALG -sha256 -subj "${subject[usr]}" -out usrcert.csr -passout pass:"${pass[usr]}" -keyout usrkey.pem -batch;
	fi
	#$qopenssl req -text -noout -verify -in usrcert.csr -config $conffile;
	$qopenssl ca -config $conffile -name InterCA -cert inter/cacert.pem -keyfile inter/cakey.pem -passin pass:"${pass[inter]}" -extensions v3_client -out usrcert.pem -batch -days 365 -infiles usrcert.csr;
	#$qopenssl x509 -purpose -in usrcert.pem ;
	$qopenssl verify -verbose -CAfile root/cacert.pem -untrusted inter/cacert.pem usrcert.pem;
	if [ $? -eq 0 ]; then
		_success "Client cert/key generated"
	else
		haserr=1
		_err "Error"
	fi
done

if [ $haserr -eq 0 ]; then
	_success "All certificates generated successfully"
else
	_warn "Failed to generate some certificates"
fi

cd $BASE_DIR
exit 0
