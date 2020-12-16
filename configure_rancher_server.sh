#!/bin/bash

admin_password=${1:-password}
rancher_version=${2:-stable}
rancher_ip=${3:-"127.0.0.1"}
k8s_version=$4
curlimage="appropriate/curl"
jqimage="stedolan/jq"

echo "Setting rancher server on ${rancher_ip} with version ${rancher_version} and k8 version ${k8s_version}"

for image in $curlimage $jqimage "rancher/rancher:${rancher_version}"; do
  until docker inspect $image > /dev/null 2>&1; do
    echo "Pulling ${image}"
    docker pull -q $image
    echo "Pull ${image} done"
    sleep 2
  done
done

echo "Starting rancher ${rancher_version}"
docker run -d --restart=unless-stopped --privileged -p 80:80 -p 443:443 -v /opt/rancher:/var/lib/rancher rancher/rancher:${rancher_version}

# wait until rancher server is ready
while true; do
  docker run --rm --net=host $curlimage -sLk https://127.0.0.1/ping && break
  sleep 5
done
echo "rancher ${rancher_version} is up and running"

# Login
while true; do
    echo "Logging in"
    LOGINRESPONSE=$(docker run \
        --rm \
        --net=host \
        $curlimage \
        -s "https://127.0.0.1/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"admin"}' --insecure)
    LOGINTOKEN=$(echo $LOGINRESPONSE | docker run --rm -i $jqimage -r .token)

    if [ "$LOGINTOKEN" != "null" ]; then
        echo "Logged in!"
        break
    else
        sleep 5
    fi
done


# Change password
echo "Changing password"
docker run --rm --net=host $curlimage -s 'https://127.0.0.1/v3/users?action=changepassword' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"admin","newPassword":"'$admin_password'"}' --insecure

# Create API key
echo "Creating API key"
APIRESPONSE=$(docker run --rm --net=host $curlimage -s 'https://127.0.0.1/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation"}' --insecure)

# Extract and store token
APITOKEN=`echo $APIRESPONSE | docker run --rm -i $jqimage -r .token`

# Configure server-url
echo "Configuring server-url"
RANCHER_SERVER="https://${rancher_ip}"
docker run --rm --net=host $curlimage -s 'https://127.0.0.1/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"'$RANCHER_SERVER'"}' --insecure

# Create cluster
echo "Creating quickstart cluster"
CLUSTERRESPONSE=$(docker run --rm --net=host $curlimage -s 'https://127.0.0.1/v3/cluster' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"dockerRootDir":"/var/lib/docker","enableNetworkPolicy":false,"type":"cluster","rancherKubernetesEngineConfig":{"kubernetesVersion":"'$k8s_version'","addonJobTimeout":30,"ignoreDockerVersion":true,"sshAgentAuth":false,"type":"rancherKubernetesEngineConfig","authentication":{"type":"authnConfig","strategy":"x509"},"network":{"options":{"flannelBackendType":"vxlan"},"plugin":"canal","canalNetworkProvider":{"iface":"eth0"}},"ingress":{"type":"ingressConfig","provider":"nginx"},"monitoring":{"type":"monitoringConfig","provider":"metrics-server"},"services":{"type":"rkeConfigServices","kubeApi":{"podSecurityPolicy":false,"type":"kubeAPIService"},"etcd":{"creation":"12h","extraArgs":{"heartbeat-interval":500,"election-timeout":5000},"retention":"72h","snapshot":false,"type":"etcdService","backupConfig":{"enabled":true,"intervalHours":12,"retention":6,"type":"backupConfig"}}}},"localClusterAuthEndpoint":{"enabled":true,"type":"localClusterAuthEndpoint"},"name":"quickstart"}' --insecure)

# Extract clusterid to use for generating the docker run command
CLUSTERID=`echo $CLUSTERRESPONSE | docker run --rm -i $jqimage -r .id`

# Generate registrationtoken
echo "Generating registration token"
docker run --rm --net=host $curlimage -s 'https://127.0.0.1/v3/clusterregistrationtoken' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure

echo "Everything done"
exit 0