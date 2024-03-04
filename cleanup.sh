#!/bin/bash

set -e
basedir=$(dirname $(readlink -f $0))
cd $basedir

gitea_host=git.gitea.local
harbor_host=registry.harbor.local
harbor_nodeport=30021
act_runner_dir=act_runner

# minikube
minikube delete

# cli
sudo rm -f /usr/local/bin/argocd
sudo rm -f /usr/local/bin/tea
which socat && sudo apt remove -y socat

# port-forward
ps -ef | grep socat | grep -v grep && pkill socat

# hosts
# sed -i not work
sed -e "/$gitea_host/d; /$harbor_host/d" /etc/hosts > /tmp/hosts
sudo cp /tmp/hosts /etc/hosts
rm -f /tmp/hosts

# act_runner
ps -ef | grep "act_runner daemon" | grep -v grep && pkill act_runner
rm -rf $act_runner_dir

# spring-boot app
rm -rf gs-spring-boot-docker
rm -rf java-app
rm -rf java-app-manifest

# docker
docker image ls | grep "$harbor_host:$harbor_nodeport/library/java-app:latest" && docker rmi $harbor_host:$harbor_nodeport/library/java-app:latest
rm -f /tmp/java-app.tar

# log
rm -f setup_log.md
