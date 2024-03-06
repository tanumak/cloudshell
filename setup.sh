#!/bin/bash

set -e
basedir=$(dirname $(readlink -f $0))
cd $basedir

. functions

portforward_java_app=8080
portforward_argocd=8081
portforward_gitea=8082
portforward_harbor=8083

argocd_pass=Argocd12345
argocd_pass_hash='$2a$10$RSzTSyjIVZAERv639AI0GuVJ6zfrABF9n22/aEbfQuXxSj81QdS4u' # Argocd12345

gitea_user=gitea
gitea_pass=Gitea12345
gitea_host=git.gitea.local
gitea_nodeport_http=30011
gitea_nodeport_ssh=30011

harbor_user=admin
harbor_pass=Harbor12345
harbor_host=registry.harbor.local
harbor_nodeport=30021

java_app_nodeport=31001

act_runner_dir=act_runner

nodeport_forward_type=socat

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
  helm_install "argocd" "argo/argo-cd" "argocd" "--set configs.params.\"server\.insecure\"=true --set configs.secret.argocdServerAdminPassword='$argocd_pass_hash'" || fail
  ok
else ok
fi

# cli
echo -n "argocd cli check ..."
if ! argocd_check_cli; then
  ng
  echo -n "argocd cli install ... "
  argocd_install_cli || fail
  ok
else ok
fi
echo -n "gitea cli check ..."
if ! gitea_check_cli; then
  ng
  echo -n "gitea cli install ... "
  gitea_install_cli || fail
  ok
else ok
fi

# socat
echo -n "socat check ..."
if ! socat_check_cli; then
  ng
  echo -n "socat install ... "
  socat_install_cli || fail
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
  check_listening $portforward_argocd && fail
  kubectl_portforward "svc/argocd-server" "$portforward_argocd:80" "argocd" || fail
  ok
else ok
fi
echo -n "login argocd ... "
retry 3 argocd_login $portforward_argocd $argocd_pass || fail
ok

# gitea
echo -n "gitea check install ... "
if ! kubectl_check_ns "gitea" || ! argocd_check_app "gitea"; then
  ng
  echo -n "gitea install ... "
  kubectl_wait "--for=condition=Ready pod -l app.kubernetes.io/name=argocd-repo-server" "argocd" || fail
  argocd_create_helm_app "gitea" "https://dl.gitea.com/charts/" "gitea" "10.1.2" "gitea" "--values-literal-file $basedir/helm/gitea.yaml --self-heal --auto-prune" || fail
  ok
else ok
fi

# harbor
echo -n "harbor check install ... "
if ! kubectl_check_ns "harbor" || ! argocd_check_app "harbor"; then
  ng
  echo -n "harbor install ... "
  kubectl_wait "--for=condition=Ready pod -l app.kubernetes.io/name=argocd-repo-server" "argocd" || fail
  argocd_create_helm_app "harbor" "https://helm.goharbor.io/" "harbor" "1.14.0" "harbor" "--values-literal-file $basedir/helm/harbor.yaml --self-heal --auto-prune" || fail
  ok
else ok
fi

# minikube ip
echo -n "get minikube ip ... "
minikube_ip=$(exec_command_out "minikube ip")
test -z $minikube_ip && fail
ok

# gitea port-forward
if [ "$nodeport_forward_type" == "socat" ]; then
  echo -n "port-foward check for gitea ... "
  if ! socat_check_portforward "$portforward_gitea" "$minikube_ip" "$gitea_nodeport_http"; then
    ng
    echo -n "port-foward for gitea ... "
    check_listening $portforward_gitea && fail
    socat_portforward "$portforward_gitea" "$minikube_ip" "$gitea_nodeport_http" || fail
    ok
  else ok
  fi
else
  echo -n "gitea condition check ... "
  retry 3 kubectl_wait_exists "ns" "gitea" || fail
  retry 3 kubectl_wait_exists "deploy" "gitea" "gitea" || fail
  kubectl_wait "--for=condition=available deployment/gitea" "gitea" || fail
  ok
  echo -n "port-foward check for gitea ... "
  if ! kubectl_check_portforward "svc/gitea-http" "$portforward_gitea:3000" "gitea"; then
    ng
    echo -n "port-foward for gitea ... "
    check_listening $portforward_gitea && fail
    kubectl_portforward "svc/gitea-http" "$portforward_gitea:3000" "gitea" || fail
    ok
  else ok
  fi
fi

# harbor port-forward
if [ "$nodeport_forward_type" == "socat" ]; then
  echo -n "port-foward check for harbor ... "
  if ! socat_check_portforward "$portforward_harbor" "$minikube_ip" "$harbor_nodeport"; then
    ng
    echo -n "port-foward for harbor ... "
    check_listening $portforward_harbor && fail
    socat_portforward "$portforward_harbor" "$minikube_ip" "$harbor_nodeport" || fail
    ok
  else ok
  fi
else
  echo -n "harbor condition check ... "
  retry 3 kubectl_wait_exists "ns" "harbor" || fail
  retry 3 kubectl_wait_exists "deploy" "harbor-core" "harbor" || fail
  kubectl_wait "--for=condition=available deployment/harbor-core" "harbor" || fail
  kubectl_wait "--for=condition=ready pod -l component=nginx" "harbor" || fail
  ok
  echo -n "port-foward check for harbor ... "
  if ! kubectl_check_portforward "svc/harbor" "$portforward_harbor:80" "harbor"; then
    ng
    echo -n "port-foward for harbor ... "
    check_listening $portforward_harbor && fail
    kubectl_portforward "svc/harbor" "$portforward_harbor:80" "harbor" || fail
    ok
  else ok
  fi
fi

# hosts
echo -n "check hosts ... "
hosts_check "$gitea_host" $minikube_ip || hosts_update "$gitea_host" $minikube_ip || fail
hosts_check "$harbor_host" $minikube_ip || hosts_update "$harbor_host" $minikube_ip || fail
hosts_check_minikube "$harbor_host" $minikube_ip || hosts_update_minikube "$harbor_host" $minikube_ip || fail
ok

# harbor login
if [ "$nodeport_forward_type" == "socat" ]; then
  echo -n "harbor condition check ... "
  retry 3 kubectl_wait_exists "ns" "harbor" || fail
  retry 3 kubectl_wait_exists "deploy" "harbor-core" "harbor" || fail
  kubectl_wait "--for=condition=available deployment/harbor-core" "harbor" || fail
  kubectl_wait "--for=condition=ready pod -l component=nginx" "harbor" || fail
  ok
fi
echo -n "login harbor ... "
retry 3 harbor_login "http://$harbor_host:$harbor_nodeport/" "$harbor_user" "$harbor_pass" || fail
ok

# gitea setting
if [ "$nodeport_forward_type" == "socat" ]; then
  echo -n "gitea condition check ... "
  retry 3 kubectl_wait_exists "ns" "gitea" || fail
  retry 3 kubectl_wait_exists "deploy" "gitea" "gitea" || fail
  kubectl_wait "--for=condition=available deployment/gitea" "gitea" || fail
  ok
fi
for repo in java-app java-app-manifest; do
  echo -n "check gitea repo ($repo) ... "
  if ! gitea_check_repo "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo; then
    ng
    echo -n "create gitea repo ($repo) ... "
    gitea_create_repo "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo || fail
    ok
  else ok
  fi
done
echo -n "set gitea secret for harbor ... "
gitea_set_secret "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass "harbor_username" $harbor_user || fail
gitea_set_secret "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass "harbor_password" $harbor_pass || fail
ok
echo -n "set gitea user access token ... "
if !  gitea_check_access_token "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass "pat"; then
  gitea_token=$(gitea_create_access_token "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass "pat" '["write:issue","write:repository","write:user"]')
  gitea_set_secret "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass "pat" "$gitea_token" || fail
fi
ok

# spring-boot app
echo -n "check spring boot app ... "
test -f "gs-spring-boot-docker" && fail
if ! test -d "gs-spring-boot-docker/complete"; then
  ng
  echo -n "clone spring boot app ... "
  exec_command "git clone --depth 1 https://github.com/spring-guides/gs-spring-boot-docker.git" || fail
  exec_command "cp -p gs-spring-boot-docker/.gitignore gs-spring-boot-docker/complete" || fail
  exec_command "ln -s gs-spring-boot-docker/complete java-app" || fail
fi
ok
echo -n "check spring boot app workflow ... "
if ! test -f "java-app/.gitea/workflows/java-app-workflow.yaml"; then
  exec_command "mkdir -p java-app/.gitea/workflows" || fail
  exec_command "cp -p $basedir/misc/java/java-app-workflow.yaml java-app/.gitea/workflows/java-app-workflow.yaml" || fail
  ok
  echo -n "update spring boot app message ... "
  exec_command "cp -p $basedir/misc/java/Application.java java-app/src/main/java/hello/Application.java" || fail
  ok
  echo -n "update spring boot app Dockerfile ... "
  exec_command "cp -p $basedir/misc/java/Dockerfile java-app/Dockerfile" || fail
fi
ok
exec_command "pushd java-app"
echo -n "check spring boot app git ... "
if ! test -d ".git"; then
  exec_command "git init" || fail
  exec_command "git branch -m main" || fail
  exec_command "git add -A" || fail
  exec_command "git -c user.email=gitea@gitea.local -c user.name=gitea commit -m 'initial commit'" || fail
  exec_command "git remote add origin http://$gitea_user:$gitea_pass@$gitea_host:$gitea_nodeport_http/$gitea_user/java-app.git" || fail
  exec_command "git push origin main" || fail
fi
ok
exec_command "popd"
echo -n "check spring boot app manifest git ... "
if ! test -d "java-app-manifest"; then
  exec_command "mkdir java-app-manifest" || fail
  exec_command "cp -p $basedir/misc/java/java-app-manifest.yaml java-app-manifest/java-app-manifest.yaml" || fail
fi
exec_command "pushd java-app-manifest"
if ! test -d ".git"; then
  exec_command "git init" || fail
  exec_command "git branch -m main" || fail
  exec_command "git add -A" || fail
  exec_command "git -c user.email=gitea@gitea.local -c user.name=gitea commit -m 'initial commit'" || fail
  exec_command "git remote add origin http://$gitea_user:$gitea_pass@$gitea_host:$gitea_nodeport_http/$gitea_user/java-app-manifest.git" || fail
  exec_command "git push origin main" || fail
fi
ok
exec_command "popd"

exec_command "pushd java-app"

echo -n "check java 17 ... "
java_set_17 || fail
ok

echo -n "build spring boot jar ... "
exec_command "mvn --batch-mode --update-snapshots verify" || fail
exec_command "mkdir -p target/extracted" || fail
exec_command "java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted" || fail
ok

echo -n "build spring boot container image ... "
exec_command "docker build -t $harbor_host:$harbor_nodeport/library/java-app:stable ." || fail
exec_command "docker push $harbor_host:$harbor_nodeport/library/java-app:stable" || fail
ok

exec_command "popd"

echo -n "check argocd java-app ... "
if ! argocd_check_app "java-app"; then
  ng
  echo -n "create java-app ... "
  kubectl_wait "--for=condition=Ready pod -l app.kubernetes.io/name=argocd-repo-server" "argocd" || fail
  argocd_create_git_app "java-app" "http://gitea-http.gitea.svc.cluster.local:3000/$gitea_user/java-app-manifest.git" "." "default" "--self-heal --auto-prune" || fail
  ok
else ok
fi

echo -n "port-foward check for java-app ... "
if ! socat_check_portforward "$portforward_java_app" "$minikube_ip" "$java_app_nodeport"; then
  ng
  echo -n "port-foward for java-app ... "
  check_listening $portforward_java_app && fail
  socat_portforward "$portforward_java_app" "$minikube_ip" "$java_app_nodeport" || fail
  ok
else ok
fi

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

# enable actions
for repo in java-app java-app-manifest; do
  echo -n "check gitea actions ($repo) ... "
  if ! gitea_check_repo_actions "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo; then
    ng
    echo -n "enable gitea actions ($repo) ... "
    gitea_enable_repo_actions "$gitea_host:$gitea_nodeport_http" $gitea_user $gitea_pass $repo || fail
    ok
  else ok
  fi
done

### URL
if google_cloudshell; then
  eval " $(grep WEB_HOST /etc/environment)"
  echo
  echo "--------------------------------------------------------------------------------"
  echo "Argo CD WEB UI (browser)"
  echo "  https://$portforward_argocd-$WEB_HOST/"
  echo "  Username: admin, Password: $argocd_pass"
  echo "--------------------------------------------------------------------------------"
  echo "Gitea WEB UI (browser)"
  echo "  https://$portforward_gitea-$WEB_HOST/"
  echo "  Username: $gitea_user, Password: $gitea_pass"
  echo
  echo "Gitea CLI (git command)"
  echo "  http://$gitea_host:$gitea_nodeport_http"
  echo "  ssh://$gitea_host:$gitea_nodeport_ssh"
  echo "  Username: $gitea_user, Password: $gitea_pass"
  echo "--------------------------------------------------------------------------------"
  echo "Harbor WEB UI (browser)"
  echo "  https://$portforward_harbor-$WEB_HOST/"
  echo "  Username: $harbor_user, Password: $harbor_pass"
  echo
  echo "Harbor CLI (docker command)"
  echo "  http://$harbor_host:$harbor_nodeport"
  echo "  Username: $harbor_user, Password: $harbor_pass"
  echo "--------------------------------------------------------------------------------"
  echo "Java Web App"
  echo "  https://$portforward_java_app-$WEB_HOST/"
  echo
  echo "Java Web App (curl, etc.)"
  echo "  http://localhost:$portforward_java_app"
  echo "--------------------------------------------------------------------------------"
else
  echo
  echo "--------------------------------------------------------------------------------"
  echo "Argo CD WEB UI (browser)"
  echo "  http://localhost:$portforward_argocd/"
  echo "  Username: admin, Password: $argocd_pass"
  echo "--------------------------------------------------------------------------------"
  echo "Gitea WEB UI (browser)"
  echo "  http://localhost:$portforward_gitea/"
  echo "  http://$gitea_host:$gitea_nodeport_http/"
  echo "  Username: $gitea_user, Password: $gitea_pass"
  echo
  echo "Gitea CLI (git command)"
  echo "  http://$gitea_host:$gitea_nodeport_http"
  echo "  ssh://$gitea_host:$gitea_nodeport_ssh"
  echo "  Username: $gitea_user, Password: $gitea_pass"
  echo "--------------------------------------------------------------------------------"
  echo "Harbor WEB UI (browser)"
  echo "  http://localhost:$portforward_harbor/"
  echo "  http://$harbor_host:$harbor_nodeport"
  echo "  Username: $harbor_user, Password: $harbor_pass"
  echo
  echo "Harbor CLI (docker command)"
  echo "  http://$harbor_host:$harbor_nodeport"
  echo "  Username: $harbor_user, Password: $harbor_pass"
  echo "--------------------------------------------------------------------------------"
  echo "Java Web App (curl, etc.)"
  echo "  http://localhost:$portforward_java_app"
  echo "--------------------------------------------------------------------------------"
fi
