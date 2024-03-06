# Cloud Shell で始める GitOps - Gitea Actions

## はじめに

このガイドでは Gitea Actions による CI と Argo CD による CD を確認します。

セットアップをしていない場合は以下を先に実施してください。
```bash
teachme ~/cloudshell/tutorial/setup.md
```

**所要時間**: 約 10 分

**前提条件**: なし

**[開始]** ボタンをクリックして次のステップに進みます。


## 構成の確認

セットアップで構築した環境は以下のようになっていて、Gitea Actions による CI、Argo CD による CD の GitOps を確認できるようになっています。

[![gitops 2](https://$LIGHTTPD_PORT-$WEB_HOST/gitops_2.png)](https://$LIGHTTPD_PORT-$WEB_HOST/gitops_2.png)

- **Spring Boot アプリコードリポジトリ**
    - Gitea の [java-app リポジトリ](https://8082-$WEB_HOST/gitea/java-app/)
    - Spring Boot のサンプルアプリと以下の処理をする [Gitea Actions のワークフロー](https://8082-$WEB_HOST/gitea/java-app/src/branch/main/.gitea/workflows/java-app-workflow.yaml)を格納
        - Spring Boot アプリのビルド
        - コンテナイメージのビルド
        - コンテナレジストリへの登録
        - マニフェストのイメージタグ変更
        - マニフェストリポジトリへのプルリクエスト

- **コンテナレジストリ**
    - Harbor の [library/java-app](https://8083-$WEB_HOST/harbor/projects/1/repositories/java-app/artifacts-tab) にイメージを格納

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

2. ワークフローを確認（オプション）
```bash
cat .gitea/workflows/java-app-workflow.yaml
```
※ ほぼ GitHub Actions と同じですが、プルリクエストのみうまく動かなかったため、Gitea の CLI を使ってプルリクエストを発行しています

3. コンテンツのメッセージの変更  
（Hello GitOps World → Gitea Actions World）
```bash
sed -i -e 's/Hello GitOps/Gitea Actions/' src/main/java/hello/Application.java 
```

4. 変更の確認
```bash
git diff
```

5. コミット
```bash
git -c user.email=gitea -c user.name=gitea commit -am "change message"
```

6. プッシュ
```bash
git push origin main
```

7. Gitea の WEB UI で以下を確認
- java-app リポジトリの [Actions](https://8082-$WEB_HOST/gitea/java-app/actions) からワークフローの実行結果（完了まで 2 分弱かかります）
[![gitea actions](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_actions.png)](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_actions.png)
- java-app-manifest の[ブランチ](https://8082-$WEB_HOST/gitea/java-app-manifest/branches)と[プルリクエスト](https://8082-$WEB_HOST/gitea/java-app-manifest/pulls)

8. Harbor の WEB UI で [library/java-app](https://8083-$WEB_HOST/harbor/projects/1/repositories/java-app/artifacts-tab) にコミットハッシュ値のタグが追加されていることを確認
[![harbor tag](https://$LIGHTTPD_PORT-$WEB_HOST/harbor_tag.png)](https://$LIGHTTPD_PORT-$WEB_HOST/harbor_tag.png)

CI が無事に完了していることを確認出来たら、次に進みましょう。

## Argo CD への Webhook

マニフェストリポジトリのプルリクエストをマージして、Argo CD で SYNC されると環境に反映されます。  
5 分間隔の AUTO SYNC や手動で SYNC することでも反映できますが、ここでは Gitea のマニフェストリポジトリに Argo CD への Webhook を作成してリアルタイムに反映させます。

### Webhook 設定

java-app-manifest リポジトリの [Webhook の設定ページ](https://8082-$WEB_HOST/gitea/java-app-manifest/settings/hooks/gitea/new)を開きます。

下記の通りに設定して Webhook を追加しましょう。（以下以外はデフォルトのまま）

**ターゲットURL**:  
`http://argocd-server.argocd.svc.cluster.local/api/webhook`

**ブランチフィルター**: `main`
[![gitea webhook](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_webhook.png)](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_webhook.png)

「Webhook を追加」をクリックして追加されたら、追加された URL を再度選択して編集画面に入って一番下のテスト配信を行って問題なく動くことを確認しましょう。
[![gitea webhook](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_webhook_2.png)](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_webhook_2.png)

Webhook が正常に設定できたことを確認出来たら、次に進みましょう。

## マージ 確認

マージする前に Argo CD の [WEB UI](https://8081-$WEB_HOST/applications/argocd/java-app) を開いておきましょう。
また、コマンドラインで以下を実行してコンテンツの切り替わりを確認できるようにしておきます。
```bash
while :; do curl -m 1 localhost:8080; sleep 0.2; done
```

準備ができたら[プルリクエスト](https://8082-$WEB_HOST/gitea/java-app-manifest/pulls) からマージコミットを作成しましょう。
[![gitea merge](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_merge.png)](https://$LIGHTTPD_PORT-$WEB_HOST/gitea_merge.png)

マージすると即時 Argo CD に反映されるのが確認できます。

[![argocd rolling](https://$LIGHTTPD_PORT-$WEB_HOST/argocd_java_app_rolling.png)](https://$LIGHTTPD_PORT-$WEB_HOST/argocd_java_app_rolling.png)


## Complete!

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

これで Gitea Actions と Argo CD による CI/CD の確認は終わりです。

---

### 各種情報表示

URL や認証情報などまとめて表示

```bash
teachme ~/cloudshell/tutorial/info.md
```
