# Cloud Shell で始める GitOps

## はじめに

このガイドでは Cloud Shell でチュートリアルを始める下準備について説明します。

**所要時間**: 約 5 分

**前提条件**: なし

**[開始]** ボタンをクリックして次のステップに進みます。


## Cloud Shell 環境の確認

Cloud Shell は以下の 2 種類のスペックがあるようです。
- 2 CPU, 8 GB メモリ
- 4 CPU, 16 GB メモリ

現在使用している環境がどちらかは以下で確認できます。
```bash
~/cloudshell_open/cloudshell/showspec.sh
```

2 CPU, 8 GB メモリの場合、GitOps のチュートリアルを進める際に多少時間がかかります。  
気になる場合は別の Google アカウントに変更して 4 CPU, 16 GB メモリ環境を探してみてください。  
(Google アカウントによって環境は固定のようです)

## チュートリアル資材のセットアップ

以下のコマンドでチュートリアルの資材を作成します。

```bash
ln -s ~/cloudshell_open/cloudshell ~/cloudshell
cd ~/cloudshell/tutorial
```
```bash
make
```

表示された URL にアクセスし、Cloud Shell と同じアカウントを選択して `ok` と表示されたら完了です。


## Complete!

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

これでチュートリアルの準備が整いました。  
続いて以下のチュートリアルで環境をセットアップしましょう。

---

### セットアップチュートリアル

GitOps 環境を構築してアクセス確認するチュートリアル
```bash
teachme ~/cloudshell/tutorial/setup.md
```
