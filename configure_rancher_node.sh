#!/bin/bash
rancher_server_ip=${1:-172.22.101.101}
admin_password=${2:-password}
rancher_version=${3:-"v2.5.3"}
curlimage="appropriate/curl"
jqimage="stedolan/jq"
agentimage="rancher/rancher-agent:${rancher_version}"

echo "Setting up agent node against server ${rancher_server_ip} with version ${rancher_version}"

agent_ip=`ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`
echo $agent_ip `hostname` >> /etc/hosts

for image in $curlimage $jqimage $agentimage; do
  until docker inspect $image > /dev/null 2>&1; do
    echo "Pulling ${image}"
    docker pull -q $image
    echo "Pull ${image} done"
    sleep 2
  done
done

echo "Checking if rancher is up at https://${rancher_server_ip}"
while true; do
  docker run --rm $curlimage -sLk https://$rancher_server_ip/ping && break
  sleep 5
done
echo "rancher is up"

# Login
while true; do

    LOGINRESPONSE=$(docker run \
        --rm \
        $curlimage \
        -s "https://$rancher_server_ip/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'$admin_password'"}' --insecure)
    LOGINTOKEN=$(echo $LOGINRESPONSE | docker run --rm -i $jqimage -r .token)

    if [ "$LOGINTOKEN" != "null" ]; then
        break
    else
        sleep 5
    fi
done

# Test if cluster is created
while true; do
  echo "Checking if quickstart cluster is created"
  CLUSTERID=$(docker run \
    --rm \
    $curlimage \
      -sLk \
      -H "Authorization: Bearer $LOGINTOKEN" \
      "https://$rancher_server_ip/v3/clusters?name=quickstart" | docker run --rm -i $jqimage -r '.data[].id')

  if [ -n "$CLUSTERID" ]; then
    echo "Cluster quickstart is created!"
    break
  else
    sleep 5
  fi
done

if [ `hostname` == "node-01" ]; then
  ROLEFLAGS="--etcd --controlplane --worker"
else
  ROLEFLAGS="--worker"
fi
echo "Adding ${ROLEFLAGS} flags to this node"

# Get node command
while true; do
  echo "Getting node command"
  AGENTCMD=$(docker run \
    --rm \
    $curlimage \
      -sLk \
      -H "Authorization: Bearer $LOGINTOKEN" \
      "https://$rancher_server_ip/v3/clusterregistrationtoken?clusterId=$CLUSTERID" | docker run --rm -i $jqimage -r '.data[].nodeCommand' | head -1)
  if [ -n "$AGENTCMD" ]; then
    echo "Got agent command!"
    break
  else
    sleep 5
  fi
done

# Show the command
COMPLETECMD="$AGENTCMD $ROLEFLAGS --internal-address $agent_ip --address $agent_ip "
echo "Running agent with the following command: ${COMPLETECMD}"
$COMPLETECMD