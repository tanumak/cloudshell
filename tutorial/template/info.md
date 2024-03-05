# Cloud Shell で始める GitOps

## 各種情報一覧

### WEB UI

#### Argo CD
- [https://8081-$WEB_HOST/](https://8081-$WEB_HOST/)
- `admin`
```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{$.data.password}' | base64 -d; echo
```

#### Gitea
- [https://8082-$WEB_HOST/](https://8082-$WEB_HOST/)
- `gitea`
- `Gitea12345`

#### Harbor

- [https://8083-$WEB_HOST/](https://8083-$WEB_HOST/)
- `admin`
- `Harbor12345`

### Spring Boot アプリ

- [https://8080-$WEB_HOST/](https://8080-$WEB_HOST/)

### コマンド

- xxx
```bash
kubectl exec -it deploy/gitea -n gitea -- /bin/sh
```
