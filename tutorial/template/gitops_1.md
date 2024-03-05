# Cloud Shell で始める GitOps - Argo CD

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

## マニフェストの変更

以下で実際にマニフェストを変更して、反映を確認します。  

---
### Pod の数を変更してプッシュ

1. マニフェストディレクトリに移動  
   ※ setup 実行時に ~/cloudshell/java-app-manifest にクローンされています
```bash
cd ~/cloudshell/java-app-manifest
```

2. Pod の数を 1 から 3 に増やします
```bash
sed -i -e 's/replicas: .*/replicas: 3/' java-app-manifest.yaml
```

3. 変更の確認
```bash
git diff
```
4. コミット
```bash
git -c user.email=gitea -c user.name=gitea commit -am "replicas 3"
```

5. プッシュ
```bash
git push origin main
```

6. Gitea の [WEB UI](https://8082-$WEB_HOST/gitea/java-app-manifest) で確認

これでマニフェストが変更されたので、Argo CD によって自動的に環境が変更されます。  
急いで次のステップに進みましょう。


## Argo CD の SYNC

マニフェストが変更されたため、Argo CD によって変更が検知され自動的に Pod が 3 つに増えます。（AUTO SYNC が有効のため）  

ただし、デフォルトでは変更のポーリングが 5 分間隔であるため、すぐに反映させたい場合は Argo CD の上部の SYNC を実行します。

SYNC が実行されると画面上で Pod が増えたことが確認できます。  

![argocd replicas 3](https://$LIGHTTPD_PORT-$WEB_HOST/argocd_java_app_replicas3.png)

なお、8080 番ポートを java-app の NodePort サービスに向けているので、以下を実行して複数の Pod が応答することを確認できます。
```bash
for i in {1..10}; do curl -s localhost:8080; done
```

## Complete!

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

これで Argo CD によるマニフェスト反映の確認は終わりです。  
続いて以下のチュートリアルで Gitea Actions を含めた CI/CD を体験してみましょう。

---

### GitOps チュートリアル (2)

ソースを変更して Gitea Actions による CI （ビルド、イメージプッシュ、マニフェストのプルリクエスト）を確認し、マニフェストの手動マージ（承認）で Argo CD による反映を確認するチュートリアル

```bash
teachme ~/cloudshell/tutorial/gitops_2.md
```

---

### 各種情報表示

URL や認証情報などまとめて表示

```bash
teachme ~/cloudshell/tutorial/info.md
```
