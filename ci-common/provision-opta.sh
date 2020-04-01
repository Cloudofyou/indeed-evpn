#!/bin/bash

set -e

check_state(){
if [ "$?" != "0" ]; then
    echo "ERROR on previous command - Exit with failure"
    exit 1
fi
}

cd ./simulation_$CI_PROJECT_NAME

echo "NetQ Master Boostrap...takes several minutes"
bootstrap=`echo $NETQ_BOOTSTRAP_TARBALL | base64 -d`
vagrant ssh netq-ts -c "netq bootstrap master interface eth0 tarball $bootstrap" > /dev/null 2>&1

echo "made it past bootstrap"

echo "NetQ OPTA Install...takes several more minutes"
install=`echo $NETQ_OPTA_TARBALL | base64 -d`
vagrant ssh netq-ts -c "netq install opta standalone full interface eth0 bundle $install config-key $NETQ_CONFIG_KEY"

# For multi-site cloud deployments, a site dedicated for CI is required
# A premise name must be specificied in the CI config. This is configured as an environment variable in gitlab CI settings.
echo "Adding NetQ CLI Server"
vagrant ssh netq-ts -c "netq config add cli server api.netq.cumulusnetworks.com access-key $NETQ_ACCESS_KEY secret-key $NETQ_SECRET_KEY premise $NETQ_PREMISE_NAME port 443"

echo "Restarting NetQ agent and cli"
vagrant ssh netq-ts -c "netq config restart cli"
vagrant ssh netq-ts -c "netq config restart agent"

#cleanup step prior to testing in case a previous pipline failure occurred
echo "Performing NetQ agent decommission"
vagrant ssh netq-ts -c "bash /home/vagrant/tests/netq-decommission-inside.sh"
