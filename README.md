<div align="center">
	<img src="Pictures/PQ-Certs.png" alt="Trust chain overview" width="400" height="auto"> 
</div>


## Overview
This tools in this repo can be used to:
1. [pqsetup.sh](pqsetup.sh) <br>
Can be used to install [LibOQS](https://github.com/open-quantum-safe/liboqs) and the accompanying [OpenSSL fork](https://github.com/open-quantum-safe/openssl), typically for research & testing with post-quantum cryptographic algorithms.
2. [mkcerts.sh](mkcerts.sh) <br>
Can be used to quickly create CA infrastructure & accompanying certificates:
    - Root CA
    - Intermediate CA
    - OCSP signing
    - TLS Server
    - TLS Client
<br>For several different algorithms:
    - RSA
    - ECDSA
    - EdDSA
    - Falcon512
    - Falcon1024
    - Dilithium2
    - Dilithium3
    - Dilithium5
    - ~~SPHINCS<sup>+</sup>-Haraka~~	_deprecated_
    - SPHINCS<sup>+</sup>-SHA256
    - SPHINCS<sup>+</sup>-SHAKE256
    - Hybrid: ECDSA (P256) + Dilithium 2
    - Hybrid: ECDSA (P256) + Falcon512
    - Hybrid: ECDSA (P256) + SPHINCS<sup>+</sup>-SHA256
3. [openssl.cnf](openssl.cnf) <br>
Is the accompanying config file for proper execution of #2. You can modify as needed if necessary. Key sections are listed below: <pre>[RootCA]</pre> <pre>[InterCA]</pre> <pre>[v3_ca]</pre> <pre>[v3_ocsp]</pre> <pre>[v3_server]&ast;</pre>  <pre>[v3_client]&ast;</pre> 
&ast; - It is particularly important to edit the *authorityInfoAccess* attribute under these sections, as this defines the OCSP URL for certs signed with these extensions.

## Requirements
*pqsetup.sh* is written only for the Ubuntu operating system, and will likely fail on any other OS. It should be fairly simple to manipulate the script to consider other OSes though, as the restriction is primarily due to the use of the **apt** package manager for installing packages. There is also a *version check* at the beginning of the **main** function that will need to be omitted to facilitate this bypass.

*mkcerts.sh* should work fine on any Linux OS, provided the variables have been appropriately configured.

## Usage
**BEFORE** running anything, open the script in your editor of choice, look for the below section at the top of the script: 
<pre>###############################################################################
################################## IMPORTANT ##################################
###############################################################################</pre>
This section has parameters that **MUST** be appropriately set for proper execution. The default values should work fine, but you will likely want to customize certain attributes, such as the certificate subject details, passphrase, etc.

Once satisfied with the configuration, simply run the script.

## Notes
- The scripts in this rep _may_ not be executable by default.
