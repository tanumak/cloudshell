# Cloud Shell で始める GitOps - Argo CD (1)

## はじめに

このガイドでは簡単な Argo CD の動作確認をします。  

セットアップをしていない場合は以下を先に実施してください。
```bash
teachme ~/cloudshell/tutorial/setup.md
```

**所要時間**: 約 10 分

**前提条件**: なし

**[開始]** ボタンをクリックして次のステップに進みます。


## 構成の確認

セットアップで構築した環境は以下のようになっていて、簡単な GitOps を確認できるようになっています。

- **Spring Boot アプリマニフェストリポジトリ**
    - Gitea の [java-app-manifest リポジトリ](https://8082-$WEB_HOST/gitea/java-app-manifest/)
    - Kubernetes の Deployment と Service を定義した [YAML ファイル](https://8082-$WEB_HOST/gitea/java-app-manifest/src/branch/main/java-app-manifest.yaml)のみ格納

- **Argo CD**
    - 上記のマニフェストリポジトリから [java-app アプリ](https://8081-$WEB_HOST/applications/argocd/java-app)を作成済み
    - マニフェストに従ってコンテナイメージを Kubernetes 上で実行

## Argo CD の動作確認

### 設定・状態確認

Argo CD の WEB UI で [java-app](https://8081-$WEB_HOST/applications/argocd/java-app) を選択して詳細を確認します。  
以下のような画面で Pod が 1 つだけ実行されていることがわかります。

![java app](https://$LIGHTTPD_PORT-$WEB_HOST/argocd_java_app.png)

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

次のステップでは実際にマニフェストを変更して Argo CD の動きを確認しましょう。

## マニフェストの変更と SYNC

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

6. Gitea の [WEB UI](https://8082-$WEB_HOST/gitea/java-app-manifest) で確認

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
