# Cloud Shell で始める GitOps - Gitea Actions

## はじめに

このガイドでは Gitea Actions による CI と Argo CD によるマニフェスト反映を確認します。

セットアップをしていない場合は以下を先に実施してください。
```bash
teachme ~/cloudshell/tutorial/setup.md
```

**所要時間**: 約 10 分

**前提条件**: なし

**[開始]** ボタンをクリックして次のステップに進みます。


## 構成の確認

セットアップで構築した環境は以下のようになっていて、Gitea Actions による CI、Argo CD による CD の GitOps を確認できるようになっています。

- **Spring Boot アプリコードリポジトリ**
    - Gitea の [java-app リポジトリ](https://8082-$WEB_HOST/gitea/java-app/)に格納
    - Gitea Actions のワークフローを作成して以下を実行する
        - Spring Boot アプリのビルド
        - コンテナイメージのビルド
        - コンテナレジストリへの登録
        - マニフェストのイメージタグ変更
        - マニフェストリポジトリへのプルリクエスト

- **コンテナレジストリ**
    - Harbor の library/java-app にイメージを格納

- **Spring Boot アプリマニフェストリポジトリ**
    - Gitea の [java-app-manifest リポジトリ](https://8082-$WEB_HOST/gitea/java-app-manifest/)
    - Kubernetes の Deployment と Service を定義した [YAML ファイル](https://8082-$WEB_HOST/gitea/java-app-manifest/src/branch/main/java-app-manifest.yaml)のみ格納
    - Gitea Actions によるプルリクエストを手動マージすることで Argo CD によって反映

- **Argo CD**
    - 上記のマニフェストリポジトリから [java-app アプリ](https://8081-$WEB_HOST/applications/argocd/java-app)を作成済み
    - マニフェストに従ってコンテナイメージを Kubernetes 上で実行

## Gitea Actions

[Gitea Actions](https://docs.gitea.com/usage/actions/overview) は [GitHub Actions](https://github.com/features/actions) とほぼ同一の仕組みとなっています。  
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
※ ほぼ GitHub と同じなのですが、プルリクエスト部分のみうまく動かなかったため、Gitea の CLI を使ってプルリクエストを発行しています

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
git -c user.email=gitea -c user.name=gitea commit -am "workflow"
```

6. プッシュ
```bash
git push origin main
```

7. Gitea の WEB UI で以下を確認
- java-app リポジトリの [Actions](https://8082-$WEB_HOST/gitea/java-app/actions) からワークフローの実行結果（完了まで 2 分弱かかります）
- java-app-manifest の[ブランチ](https://8082-$WEB_HOST/gitea/java-app-manifest/branches)と[プルリクエスト](https://8082-$WEB_HOST/gitea/java-app-manifest/pulls)

8. Harbor の WEB UI で [library/java-app](https://8083-$WEB_HOST/harbor/projects/1/repositories/java-app/artifacts-tab) にイメージが追加されていることを確認

## マージによる反映

マニフェストリポジトリのプルリクエストをマージすると、Argo CDに反映されます。  

5 分間隔の AUTOSYNC やマニュアルの SYNC でも反映できますが、ここではマニフェストリポジトリに Argo CD への Webhook を作成してリアルタイムに反映させます。

---

### Webhook 設定

java-app-manifest リポジトリの [Webhook の設定ページ](https://8082-$WEB_HOST/gitea/java-app-manifest/settings/hooks/gitea/new)を開きます。

下記の通りに設定して Webhook を追加しましょう。

**ターゲットURL**: http://argocd-server.argocd.svc.cluster.local/api/webhook  
**ブランチフィルター**: main

さらに、追加された URL を再度選択して一番下のテスト配信を行って問題なく動くことを確認しましょう。

---

### マージ 確認

Argo CD の WEB UI を開いた状態にしておき、マニフェストのプルリクエスト画面からマージリクエストを作成してみましょう。

また、コマンドラインで以下を実行し、コンテンツが変わることを確認しましょう。
```bash
while :; do curl -m 1 localhost:8080; sleep 0.2; done
```
