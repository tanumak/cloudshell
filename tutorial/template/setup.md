# Cloud Shell で始める GitOps

## はじめに

このガイドでは Cloud Shell だけで簡単な GitOps 環境を構築して各種操作の確認をすることができます。

GitOps 環境の構成は以下のようになります。

- Argo CD (CD)
- Gitea (Git リポジトリ; GitHub の代わり)
- Gitea Actions (CI; GitHub Actions の代わり)
- Harbor (コンテナリポジトリ; ECR などの代わり)
- Spring Boot アプリ

上記全てを minikube 上で実行して、WEB UIやコマンドで操作できます。


**所要時間**: 約 10 分

**前提条件**: なし

**[開始]** ボタンをクリックして次のステップに進みます。


## 環境のセットアップ

必要な環境をセットアップするために以下のコマンドを実行します。初回の実行は 5 分程度かかります。

```bash
cd ~/cloudshell
```
```bash
./setup.sh
```

コマンドを実行すると以下のような出力で始まります。
```terminal
google cloudshell check ... ok
minikube check ... ng
minikube start ... 
```
※ `minikube start` で承認画面が出たら承認します

最後に URL などが表示されれば完了ですので次のステップに進みましょう。

---
### fail した場合

途中で `fail` と出て終わってしまった場合は、再度 `setup.sh` を実行してみてください。  
何度実行しても `fail` になる場合はセットアップのログが<walkthrough-editor-open-file filePath="cloudshell/setup_log.md">setup_log.md</walkthrough-editor-open-file>に残るので、エラーの内容を確認してください。

作成した環境を全て削除してやり直す場合は以下を実行してください。
```bash
./cleanup.sh
```


## 動作確認 (1) Argo CD

`setup.sh` の出力の最後に URL や認証情報が表示されるのでアクセスして動作を確認しましょう。  
まずは Argo CD です。

---

### Argo CD

以下の URL をクリックしてログインします。  
Google の認証が出た場合は Cloud Shell と同じアカウントを選択します。  

[https://8081-$WEB_HOST/](https://8081-$WEB_HOST/)

Argo CD のログイン画面が表示されたら、`admin`ユーザでログインします。  
パスワードはランダムで生成されますので、`setup.sh`の出力を確認してください。  
パスワードは以下のコマンドでも確認可能です。
```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{$.data.password}' | base64 -d; echo
```

![argocd login](https://$LIGHTTPD_PORT-$WEB_HOST/argocd_login.png)

ログイン後、`gitea`, `harbor`, `java-app` のアプリが表示されることを確認しましょう。

![argocd login](https://$LIGHTTPD_PORT-$WEB_HOST/argocd_app.png)


## 動作確認 (2) Gitea

次は Gitea です。

---

### Gitea

以下の URL をクリックしてログインします。  
Google の認証が出た場合は Cloud Shell と同じアカウントを選択します。  

[https://8082-$WEB_HOST/](https://8082-$WEB_HOST/)

Gitea の画面右上の「サインイン」から`gitea`ユーザでログインします。  
パスワードは `Gitea12345` です。

![gitea login](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_login.png)

ログイン後、`java-app`, `java-app-manifest` のリポジトリが表示されることを確認しましょう。

![gitea repo](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_repo.png)


## 動作確認 (3) Harbor

続いては Harbor です。

---

### Harbor

以下の URL をクリックしてログインします。  

[https://8083-$WEB_HOST/](https://8083-$WEB_HOST/)

Google の認証が出た場合は Cloud Shell と同じアカウントを選択します。  
Harbor の画面から`admin`ユーザでログインします。  
パスワードは `Harbor12345` です。

![harbor login](https://$LIGHTTPD_PORT-$WEB_HOST/harbor_login.png)


## 動作確認 (4) Spring Boot アプリ

最後に Spring Boot のアプリが動いていることを確認しましょう。

---

### Spring Boot アプリ

以下の URL をクリックします。  

[https://8080-$WEB_HOST/](https://8080-$WEB_HOST/)

curl コマンドで確認することもできます。
```bash
curl -s http://localhost:8080/
```

正常な場合は `Hello GitOps World` と表示されます。

## Complete!

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

これでセットアップは完了です。

### 他のチュートリアル

- xxx
```bash
teachme 2.md
```

- xxx
```bash
teachme 3.md
```
