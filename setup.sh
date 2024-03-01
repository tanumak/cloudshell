#!/bin/bash

set -e
basedir=$(dirname $(readlink -f $0))
cd $basedir

. functions

portforward_argocd=8081
portforward_gitea=8082
portforward_harbor=8083

gitea_user=gitea
gitea_pass=Gitea12345
gitea_host=git.gitea.local
gitea_nodeport_http=30011
gitea_nodeport_ssh=30011

harbor_user=admin
harbor_pass=Harbor12345
harbor_host=registry.harbor.local
harbor_nodeport=30021

act_runner_dir=act_runner

# docker
echo -n "google cloudshell check ... "
if google_cloudshell; then
  if ! exec_command "grep insecure-registry /etc/default/docker >/dev/null"; then
    exec_command "echo 'DOCKER_OPTS=\"$DOCKER_OPTS --insecure-registry 192.168.0.0/16\"' | sudo tee -a /etc/default/docker"
  fi
  if ! exec_command "ps -ef | grep -E docker.pid.*insecure-registry | grep -v grep >/dev/null"; then
    exec_command "sudo /etc/init.d/docker restart" || fail
  fi
fi
ok

# minikube
echo -n "minikube check ... "
if ! minikube_status; then
  ng
  echo -n "minikube start ... "
  minikube_start || fail
  ok
  echo -n "minikube check ... "
  minikube_status || fail
  ok
else ok
fi

# argocd
echo -n "argocd check repo ... "
if ! helm_check_repo "argo"; then
  ng
  echo -n "argocd add repo ... "
  helm_add_repo "argo" "https://argoproj.github.io/argo-helm" || fail
  ok
else ok
fi
echo -n "argocd check namespace ... "
if ! kubectl_check_ns "argocd"; then
  ng
  echo -n "argocd add namespace ... "
  kubectl_add_ns "argocd" || fail
  ok
else ok
fi
echo -n "argocd install check ... "
if ! helm_check_install "argocd" "argocd"; then
  ng
  echo -n "argocd install ... "
  helm_install "argocd" "argo/argo-cd" "argocd" "--set configs.params.\"server\.insecure\"=true" || fail
  ok
else ok
fi
echo -n "argocd cli check ..."
if ! argocd_check_cli; then
  ng
  echo -n "argocd cli install ... "
  argocd_install_cli || fail
  ok
else ok
fi

# argocd port-forward, login
echo -n "argocd condition check ... "
kubectl_wait "--for=condition=available deployment/argocd-server" "argocd" || fail
kubectl_wait "--for=condition=Ready pod -l app.kubernetes.io/name=argocd-server" "argocd" || fail
ok
echo -n "port-foward check for argocd ... "
if ! kubectl_check_portforward "svc/argocd-server" "$portforward_argocd:80" "argocd"; then
  ng
  echo -n "port-foward for argocd ... "
  kubectl_portforward "svc/argocd-server" "$portforward_argocd:80" "argocd" || fail
  ok
else ok
fi
echo -n "login argocd ... "
argocd_password=$(exec_command_out "kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{$.data.password}' | base64 -d")
argocd_login $portforward_argocd $argocd_password || fail
ok

# gitea
echo -n "gitea check install ... "
if ! kubectl_check_ns "gitea" || ! argocd_check_app "gitea"; then
  ng
  echo -n "gitea install ... "
  kubectl_wait "--for=condition=Ready pod -l app.kubernetes.io/name=argocd-repo-server" "argocd" || fail
  argocd_create_app "gitea" "https://dl.gitea.com/charts/" "gitea" "10.1.2" "gitea" "--values-literal-file $basedir/helm/gitea.yaml" || fail
  ok
else ok
fi

# harbor
echo -n "harbor check install ... "
if ! kubectl_check_ns "harbor" || ! argocd_check_app "harbor"; then
  ng
  echo -n "harbor install ... "
  kubectl_wait "--for=condition=Ready pod -l app.kubernetes.io/name=argocd-repo-server" "argocd" || fail
  argocd_create_app "harbor" "https://helm.goharbor.io/" "harbor" "1.14.0" "harbor" "--values-literal-file $basedir/helm/harbor.yaml" || fail
  ok
else ok
fi

# gitea port-forward
echo -n "gitea condition check ... "
kubectl_wait_exists "ns" "gitea" "5" || fail
kubectl_wait_exists "deploy" "gitea" "5" "gitea" || fail
kubectl_wait "--for=condition=available deployment/gitea" "gitea" || fail
ok
echo -n "port-foward check for gitea ... "
if ! kubectl_check_portforward "svc/gitea-http" "$portforward_gitea:3000" "gitea"; then
  ng
  echo -n "port-foward for gitea ... "
  kubectl_portforward "svc/gitea-http" "$portforward_gitea:3000" "gitea" || fail
  ok
else ok
fi

# harbor port-forward
echo -n "harbor condition check ... "
kubectl_wait_exists "ns" "harbor" "5" || fail
kubectl_wait_exists "deploy" "harbor-core" "5" "harbor" || fail
kubectl_wait "--for=condition=available deployment/harbor-core" "harbor" || fail
kubectl_wait "--for=condition=ready pod -l component=nginx" "harbor" || fail
ok
echo -n "port-foward check for harbor ... "
if ! kubectl_check_portforward "svc/harbor" "$portforward_harbor:80" "harbor"; then
  ng
  echo -n "port-foward for harbor ... "
  kubectl_portforward "svc/harbor" "$portforward_harbor:80" "harbor" || fail
  ok
else ok
fi

# hosts
echo -n "check hosts ... "
hosts_check "$gitea_host" || hosts_update "$gitea_host" || fail
hosts_check "$harbor_host" || hosts_update "$harbor_host" || fail
ok

# harbor login
echo -n "login harbor ... "
harbor_login "http://$harbor_host:$harbor_nodeport/" "$harbor_user" "$harbor_pass" || fail
ok

# gitea setting
for repo in app app-manifest; do
  echo -n "check gitea repo ($repo) ... "
  if ! gitea_check_repo "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo; then
    ng
    echo -n "create gitea repo ($repo) ... "
    gitea_create_repo "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo || fail
    ok
  else ok
  fi
  echo -n "check gitea actions ($repo) ... "
  if ! gitea_check_repo_actions "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo; then
    ng
    echo -n "enable gitea actions ($repo) ... "
    gitea_enable_repo_actions "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo || fail
    ok
  else ok
  fi
done
echo -n "set gitea secret for harbor ... "
gitea_set_secret "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass "harbor_username" $harbor_user || fail
gitea_set_secret "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass "harbor_password" $harbor_pass || fail
ok

# act_runner
echo -n "check local act runner ... "
test -f "$act_runner_dir" && fail
if ! test -f "$act_runner_dir/act_runner"; then
  ng
  test -d "$act_runner_dir" || mkdir "$act_runner_dir"
  echo -n "install act runner ... "
  curl -sLO "https://gitea.com/gitea/act_runner/releases/download/v0.2.6/act_runner-0.2.6-linux-amd64"
  mv act_runner-0.2.6-linux-amd64 "$act_runner_dir/act_runner"
  ok
else ok
fi
chmod +x "$act_runner_dir/act_runner"
echo -n "get gitea runner token ... "
runner_token=$(exec_command_out "kubectl exec svc/gitea-http -n gitea -- gitea actions generate-runner-token -s gitea 2>/dev/null")
ok
echo -n "register act_runner ... "
exec_command "$act_runner_dir/act_runner register --no-interactive --instance http://$gitea_host:$gitea_nodeport_http/ --token $runner_token --name localhost --labels localhost:host" || fail
ok
echo -n "check act_runner daemon ... "
if exec_command "ps -ef | grep 'act_runner daemon' | grep -v grep"; then
  exec_command "pkill act_runner" || fail
fi
exec_background_command "$act_runner_dir/act_runner daemon" "$act_runner_dir/localhost.log"
ok

# spring-boot app
echo -n "check spring boot app ... "
test -f "gs-spring-boot-docker" && fail
if ! test -d "gs-spring-boot-docker/complete"; then
  ng
  echo -n "clone spring boot app ... "
  exec_command "git clone --depth 1 https://github.com/spring-guides/gs-spring-boot-docker.git" || fail
  exec_command "cp -p gs-spring-boot-docker/.gitignore gs-spring-boot-docker/complete" || fail
  exec_command "ln -s gs-spring-boot-docker/complete app" || fail
fi
ok
echo -n "check spring boot app workflow ... "
if ! test -f "app/.gitea/workflows/app.yaml"; then
  exec_command "mkdir -p app/.gitea/workflows" || fail
  exec_command "cp -p $basedir/misc/java-app/java-app-workflow.yaml app/.gitea/workflows/java-app-workflow.yaml" || fail
fi
ok
exec_command "pushd app"
echo -n "check spring boot app git ... "
if ! test -d ".git"; then
  exec_command "git init" || fail
  exec_command "git branch -m main" || fail
  exec_command "git add -A ." || fail
  exec_command "git -c user.email=gitea@gitea.local -c user.name=gitea commit -m 'initial commit'" || fail
  exec_command "git remote add origin http://$gitea_user:$gitea_pass@$gitea_host:$gitea_nodeport_http/$gitea_user/app.git" || fail
fi
ok
exec_command "popd"
