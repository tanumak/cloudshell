# Cloud Shell で始める GitOps

## はじめに

このガイドでは Cloud Shell だけで簡単な GitOps 環境を構築して操作の確認をすることができます。

構成は以下のようになります。

- Argo CD (CD)
- Gitea (Git リポジトリ; GitHub の代わり)
- Gitea Actions (CI; GitHub Actions の代わり)
- Harbor (コンテナリポジトリ; ECR などの代わり)
- Spring Boot アプリ

上記全てを minikube 上で実行して、WEB UIやコマンドで操作できます。


**所要時間**: 約 30 分

**前提条件**: なし

**[開始]** ボタンをクリックして次のステップに進みます。


## 環境のセットアップ

必要な環境をセットアップするために以下のコマンドを実行します。初回の実行は 5 分程度かかります。

```bash
cd ~/cloudshell
./setup.sh
```

以下のような出力で始まり、最後に URL などが表示されれば完了です。
```terminal
google cloudshell check ... ok
minikube check ... ok
argocd check repo ... ok
argocd check namespace ... ok
argocd install check ... ok
argocd cli check ...ok
 :
```

途中で `fail` と出て終わってしまった場合は、再度 `setup.sh` を実行してみてください。  
何度実行しても `fail` になる場合は `setup_log.md` を確認しましょう。

## 動作確認

`setup.sh` の出力の最後に Argo CD などの URL が表示されるのでアクセスして動作を確認しましょう。

---

### Argo CD

以下のような URL が表示されているはずです。クリックして Google の認証が出た場合は Cloud Shell と同じアカウントを選択します。  
Argo CD のログイン画面が表示されたら、admin ユーザでログインします。(パスワードはランダムで生成されます)
```terminal
--------------------------------------------------------------------------------
Argo CD WEB UI (browser)
  https://8081-cs-277853503030-default.cs-asia-east1-jnrc.cloudshell.dev/
  Username: admin, Password: ****************
```

ログイン後、`gitea`, `harbor`, `java-app` のアプリが表示されることを確認しましょう。

---

### Gitea

Gitea についても同様にアクセスできることを確認しましょう。  
画面右上のサインインをクリックし、アカウントはユーザ名 `gitea`, パスワード `Gitea12345` でログインできます。

```terminal
--------------------------------------------------------------------------------
Gitea WEB UI (browser)
  https://8082-cs-277853503030-default.cs-asia-east1-jnrc.cloudshell.dev/
  Username: gitea, Password: Gitea12345
```

ログイン後、`java-app`, `java-app-manifest` のリポジトリが表示されることを確認しましょう。

---

### Harbor

Harbor についても同様にアクセスできることを確認しましょう。  
アカウントはユーザ名 `admin`, パスワード `Harbor12345` で作成されます。
```terminal
--------------------------------------------------------------------------------
Harbor WEB UI (browser)
  https://8083-cs-277853503030-default.cs-asia-east1-jnrc.cloudshell.dev/
  Username: admin, Password: Harbor12345
```

---

### Spring Boot アプリ

最後に Spring Boot のアプリが動いていることを確認しましょう。

```terminal
--------------------------------------------------------------------------------
Java Web App
  https://8080-cs-277853503030-default.cs-asia-east1-jnrc.cloudshell.dev/
```

正常な場合は `Hello GitOps World` と表示されます。

## 構成の確認

### 概要

ここまでで構築した環境は以下のようになっていて、簡単な GitOps を確認できるようになっています。

- **Spring Boot アプリコードリポジトリ**
    - Gitea の java-app リポジトリに格納
    - Gitea Actions のワークフローを作成して以下を実行する
        - Spring Boot アプリのビルド
        - コンテナイメージのビルド
        - コンテナレジストリへの登録
        - マニフェストのイメージタグ変更
        - マニフェストリポジトリへのプルリクエスト

- **コンテナレジストリ**
    - Harbor の library/java-app にイメージを格納

- **Spring Boot アプリマニフェストリポジトリ**
    - Gitea の java-app-manifest リポジトリに格納

- **Argo CD**
    - マニフェストリポジトリを監視
    - マニフェストに従ってコンテナレジストリからコンテナイメージを取得して、Kubernetes 上で実行する

## Argo CD の動作確認

### 設定・状態確認
Argo CD の WEB UI で `java-app` を選択して詳細を確認します。  
以下のような画面で Pod が 1 つだけ実行されていることがわかります。



また、上部の DETAIL ボタンから、以下がわかります。
- Git のリポジトリ（java-app-manifest）
- コンテナイメージ（java-app:latest）
- SYNC POLICY
    - AUTOMATED  
      リポジトリの変更を自動的に適用する  
      ※ DISABLEボタンが表示されている場合、ENABLEになっている
    - SELF HEAL  
      Pod や Service などが削除された場合に自動的に復旧する  
      ※ DISABLEボタンが表示されている場合、ENABLEになっている）

次のステップからは実際に Argo CD の動きを確認しましょう。

## マニフェストの変更とSYNC

以下で実際にマニフェストを変更して、反映を確認します。  

---
### マニフェストの変更

1. マニフェストディレクトリに移動  
   ※ setup 実行時に ~/cloudshell/java-app-manifest にクローンされています
```bash
cd ~/cloudshell/java-app-manifest
```

2. Pod の数を 1 から 3 に増やします
```bash
sed -i -e 's/replicas: 1/replicas: 3/' java-app-manifest.yaml
```

3. 変更の確認
```bash
git diff
```
4. コミット
```bash
git commit -am "replicas 3"
```

5. プッシュ
```bash
git push origin main
```

6. Gitea の WEB UI で確認（オプション）

---
### SYNC

これでマニフェストが変更されたため、Argo CD によって変更が検知され自動的に Pod が 3 つに増えます。（AUTO SYNC が有効のため）  
ただし、デフォルトでは変更のポーリングが 5 分間隔であるため、すぐに反映させたい場合は Argo CD の上部の SYNC を実行します。


SYNC が実行されると画面上で Pod が増えたことが確認できます。  
なお、8080 番ポートを java-app の NodePort サービスに向けているので、以下を実行して複数の Pod が応答することを確認できます。
```bash
for i in {1..10}; do curl -s localhost:8080; done
```
うまくいったら、次のステップに進み Gitea Actions による CI を確認していきましょう。

## Gitea Actions

Gitea Actions はほとんど GitHub Actions と同じです。  
実際にワークフローを追加して、動きを確認しましょう。

1. java-app ディレクトリに移動  
   ※ setup 実行時に ~/cloudshell/java-app にクローンされています
```bash
cd ~/cloudshell/java-app
```

2. ワークフローを確認
   ※ setup 実行時に配置されています
```bash
cat .gitea/workflows/java-app-workflow.yaml
```
※ ほぼ GitHub と同じですが、プルリクエスト部分のみうまく動かなかったため、Gitea の CLI を使ってプルリクエストを発行しています

3. ワークフローファイルを追加
```bash
git add -A
```

4. コンテンツのメッセージの変更
```bash
sed -i -e 's/Hello GitOps/Gitea Actions/' src/main/java/hello/Application.java 
```

5. コミット
```bash
git commit -am "workflow"
```

6. プッシュ
```bash
git push origin main
```

7. Gitea の WEB UI で以下を確認
- java-app リポジトリの Actions からワークフローの実行結果（完了まで 2 分弱かかります）
- java-app-manifest のブランチとプルリクエスト

8. Harbor の WEB UI で library/java-app にイメージが追加されていることを確認（オプション）

## マージによる反映

マニフェストリポジトリのプルリクエストをマージすると、Argo CDに反映されます。  

5 分間隔の AUTOSYNC やマニュアルの SYNC でも反映できますが、ここではマニフェストリポジトリに Argo CD への Webhook を作成してリアルタイムに反映させます。

---

### Webhook 設定

リポジトリの Webhook の設定ページを開きます。

Gitea > java-app-manifest > 設定 > Webhook > Webhook を追加 > Gitea

※ **URL例** https://8082-cs-略.cloudshell.dev/gitea/java-app-manifest/settings/hooks/gitea/new

**ターゲットURL**: http://argocd-server.argocd.svc.cluster.local/api/webhook  
**ブランチフィルター**: main

上記の通りに設定して Webhook を追加し、追加された URL を再度選択して一番下のテスト配信を行って問題なく動くことを確認しましょう。

---

### マージ 確認

Argo CD の WEB UI を開いた状態にしておき、マニフェストのプルリクエスト画面からマージリクエストを作成してみましょう。

また、コマンドラインで以下を実行し、コンテンツが変わることを確認しましょう。
```bash
while :; do curl -m 1 localhost:8080; sleep 0.2; done
```
