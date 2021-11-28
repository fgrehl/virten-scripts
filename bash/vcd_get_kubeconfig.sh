#!/bin/bash

# Get kubeconfig from VMware Cloud Director 10.3 with Container Service Extension
# Usage: vcd_get_kubeconfig.sh --user USER@ORG --password PASSWORD -vcd VCDURL --cluster CLUSTERNAME

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -u|--user) USER="$2"; shift ;;
    -p|--password) PASSWORD="$2"; shift ;;
    -v|--vcd) VCD="$2"; shift ;;
    -c|--cluster) CLUSTER="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z $USER || -z $PASSWORD || -z $CLUSTER || -z $VCD ]]; then
 echo 'Missing parameter. Try:'
 echo 'vcd_get_kubeconfig.sh -u USER@ORG -p PASSWORD -v VCDURL -c CLUSTERNAME'
 echo 'vcd_get_kubeconfig.sh --user USER@ORG --password PASSWORD -vcd VCDURL --cluster CLUSTERNAME'
 exit 1
fi

ACCEPT="Accept: */*;version=36.0"
CRED=$(echo -n $USER:$PASSWORD |base64)
TOKEN=$(curl -sI -k --header "$ACCEPT" --header "Authorization: Basic $CRED" --request POST https://$VCD/api/sessions | tr -d '\r' | sed -En 's/^x-vcloud-authorization: (.*)/\1/p')
CLUSTERID=$(curl -s -k --header "$ACCEPT" --header "x-vcloud-authorization: $TOKEN" --request GET https://$VCD/api/cse/3.0/cluster | jq  '.[] | select(.name=="'$CLUSTER'")' | jq -r  '.id')
curl -s -k --header "$ACCEPT" --header "x-vcloud-authorization: $TOKEN" --request GET https://$VCD/api/cse/3.0/cluster/$CLUSTERID/config | jq -r '.message'
