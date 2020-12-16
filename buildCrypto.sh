#!/bin/bash

#set -euo pipefail
#set -x

function usage {
cat << EOF
usage: $0 options

OPTIONS:
        -h | --help                              Usage information
        -d | --delete                            Delete all directories in this folder.
        -f <configfile>                          JSON config file
        -c <clientname>                          Add a client to the current environment
        -a <existing CA>                         Add a server to the current environment
EOF
}

CLEANUP=false


while true; do
  case "$1" in
    -h | --help ) usage; exit 1; shift ;;
    -d | --delete ) CLEANUP=true; shift ;;
    -f ) CONFIGFILE="$2";shift 2 ;;
    -c ) CLIENTNAME="$2";shift 2 ;;
    -s ) SERVERNAME="$2";shift 2 ;;
    -a ) CERTAUTHORITY="$2";shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ $CLEANUP == "true" ]
then
 echo -e "*** cleaning up all directories in this folder ***"
 DIR=`ls -d */`
for DIRECTORY in $DIR
do
sudo rm -r $DIRECTORY
done
fi
 

# This script will create a self-sign certificate CA.  
# You need to enter the servers you want user certificates generated for
# You can pass in a json file or we will build some defaults for you
# 
# END USER POPULATE THESE ARRAYS"


if [ -n "$CONFIGFILE" ]
then
  SERVERS=`jq .Servers[].name $CONFIGFILE | sed 's/"//g' | tr '\n' ' ' | tr '[:upper:]' '[:lower:]'`      
  CLIENTAUTH=`jq .Clients[].name $CONFIGFILE | sed 's/"//g' | tr '\n' ' ' | tr '[:upper:]' '[:lower:]'`
  CA=`jq .CertAuthority $CONFIGFILE | sed 's/"//g' | tr '[:upper:]' '[:lower:]'`
else
  SERVERS="api-endpoint consumer-endpoint apim-endpoint cm-endpoint portal-admin portal-web analytics-ac-endpoint analytics-ai-endpoint"
  CLIENTAUTH="analytics-ingestion-client analytics-client-client portal-admin-client"
  CA="ingress-ca" 
fi

echo "$SERVERS"
echo "$CLIENTAUTH"
echo "$CA"
# mainline

function create_CA {
  if [ -n "$CERTAUTHORITY" ] 
  then
   return
  fi

  mkdir $CA
  cd $CA
  
  echo -e "*** generating the ca private key ***"
  openssl genrsa -aes256 -passout pass:foobar  -out $CA-ca-key.pem 2048 
  openssl rsa -in $CA-ca-key.pem -out $CA-ca-dec-key.pem -passin pass:foobar

  echo -e "*** generate the root cert ***"
  openssl req -new -passin pass:foobar -key $CA-ca-key.pem -x509 -days 1000 -out $CA-ca.cert -subj "/CN=$CA" 

  echo -e "*** this is a self signed cert ***"
  cp $CA-ca.cert $CA-ca-root.cert

  echo -e "*** Time to create server certs ***"
}

function create_Server {
  echo -e "entering create_Server"
  if [ -n "$SERVERNAME" ] 
  then
    if [  ! -n "$CERTAUTHORITY" ] 
    then
       echo "When adding a new server with you must specify the Certificate Authority"
       exit
    fi
     CA=$CERTAUTHORITY
  fi

  if [ -n "$CLIENTNAME" ] 
  then
    return                                                            # if adding a client we need to return
  fi  

  echo "entering server loop\n"
  for NAME in $SERVERS
  do
    cd ..
    mkdir $NAME
    cd $NAME
    echo -e "*** making $NAME cert ***"
 
    openssl genrsa -aes256 -passout pass:foobar -out $NAME-server-key.pem 2048
    chmod 600 $NAME-server-key.pem
    echo "*** creating a csr for $NAME ***" 
    sed -i -e 's/BARRY/'$NAME'/g' ../myserver.cnf 
    openssl req -new -config ../myserver.cnf -keyout $NAME-server-key.pem -out $NAME.csr -subj "/O=cert-manager/CN=$NAME"
    sed -i -e 's/'$NAME'/BARRY/g' ../myserver.cnf
    echo "*** csr complete ***"
    openssl x509 -req -passin pass:foobar  -days 500 -in $NAME.csr -CA ../$CA/$CA-ca.cert -CAkey ../$CA/$CA-ca-key.pem -CAcreateserial -out $NAME-server.cert -extfile <(cat ../myserver.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:<HOST>,DNS:<HOST>\nextendedKeyUsage=serverAuth")) -extensions SAN
  done
}

function create_Client {
  echo -e "entering create_Client\n"
  
  if [ -n "$CLIENTNAME" ] 
  then
    if [  ! -n "$CERTAUTHORITY" ] 
    then
       echo "When adding a new client with you must specify the Certificate Authority"
       exit
    fi
     CLIENTAUTH=$CLIENTNAME
     CA=$CERTAUTHORITY
     cd $CA
  fi
  
  echo "entering the client loop \n"

  for NAME in $CLIENTAUTH
  do
    cd ..
    mkdir $NAME
    cd $NAME
    echo -e "*** making $NAME cert ***"
 
    openssl genrsa -aes256 -passout pass:foobar -out $NAME-client-key.pem 2048
    chmod 600 $NAME-client-key.pem
    echo "*** creating a csr for $NAME ***" 
    sed -i -e 's/BARRY/'$NAME'/g' ../myserver.cnf 
    openssl req -new -config ../myserver.cnf -keyout $NAME-client-key.pem -out $NAME.csr -subj "/O=cert-manager/CN=$NAME"
    sed -i -e 's/'$NAME'/BARRY/g' ../myserver.cnf
    echo "*** csr complete ***"
    openssl x509 -req -passin pass:foobar  -days 500 -in $NAME.csr -CA ../$CA/$CA-ca.cert -CAkey ../$CA/$CA-ca-key.pem -CAcreateserial -out $NAME-client.cert -extfile <(cat ../myserver.cnf <(printf "\n[SAN]\nkeyUsage=critical, digitalSignature, keyEncipherment\nextendedKeyUsage = clientAuth\nbasicConstraints=critical, CA:FALSE\nsubjectKeyIdentifier=hash\n")) -extensions SAN
   done
  cd ..
  rm myserver.cnf-e
} 

echo "cert generation beginning"
create_CA
create_Server
create_Client
echo "cert generations was successful!"
exit
