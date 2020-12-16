# certgenerator 
The cert generator tools is designed to create a certificate authority that will create as many user certificates as desired.

script name: buildCrypto.sh
config file: myserver.cnf

You can specify all the user's by changing two variables in the script:
```
SERVERS="outgress charlie"
CA="ingress"
```
This will create three folders, 
ingress
outgress
charlie

ingress is where the CA crypto material will be stored
outgress and charlie will include the user's crypto material

There are two ways to run the script:
./buildCrypto.sh
./buildCrypto.sh -c true

-c true is designed to remove all the existing folders is specified in the $SERVERS and $CA variables. 

Here is an example when you run the above:

```
Barrys-MBP:certgenerator bmosus.ibm.com$ ./buildCrypto.sh
Barrys-MBP:certgenerator bmosus.ibm.com$ tree

├── README.md
├── buildCrypto.sh 
├── charlie
   ├── charlie-server-key.pem
   ├── charlie-server.cert
   └── charlie.csr
├── ingress
   ├── ingress-ca-dec-key.pem
   ├── ingress-ca-key.pem
   ├── ingress-ca-root.cert
   └── ingress-ca.cert
├── myserver.cnf
|── outgress
    ├── outgress-server-key.pem
    ├── outgress-server.cert
    └── outgress.csr
```    

