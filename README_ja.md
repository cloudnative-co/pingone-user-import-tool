# PingOne User Import Tool

PingOne Platformに、CSVファイルからユーザーを一括でインポートするためのツール。

## 実行方法

環境を用意するのが面倒なので、Nix Flakesを使うことを推奨します。
以下は、Nix Flakesが利用可能な前提で使い方を説明します。

コマンドについてのヘルプを表示するには、以下のようにします。

```
nix run github:cloudnative-co/pingone-user-import-tool/flakes -- -?
```

> [!NOTE]
> 上記のnix runを実行する前に、git cloneをする必要はありません。
> 初回の実行時には、パッケージのダウンロードとビルドが実行されるため、コマンドが実行されるまでに時間がかかるので、気長に待ちましょう。



## コマンド実行前の準備

コマンドを実行するには、以下の情報が必要です。

- ユーザーの情報が含まれるCSVファイル
- 対象となる環境のEnvironment ID
- Worker AppのClient IDと、Secret ID
- ユーザーを作成するPopulationのPopulation ID

## CSVファイル

CSVファイルにはユーザーのリストを含める必要があります。最低限、各レコードには「email」と「username」の属性が必要です。
便宜上、サンプルのCSVを[こちら](https://github.com/pingidentity/pingone-customers-user-import-tool/blob/master/examples.csv)に用意しています。

本ツールは以下の属性をサポートしています：

    username
    email
    primaryPhone
    mobilePhone
    name.honorificPrefix
    name.given
    name.middle
    name.family
    name.honorificSuffix
    name.formatted
    password
    enabled

> [!WARNING]
> 値を正しく検出するため、カンマ(`,`)の間にスペースを入れないでください。
> 例: `name.honorificPrefix,name.given,name.middle,name.family,name.honorificSuffix,name.formatted,primaryPhone,mobilePhone,email,username,password,enabled`

### 事前にエンコード済みのパスワード

事前にエンコード済みのパスワードがある場合は、そのままインポートできます。
サポートされている鍵導出関数（KDF）については、[Password Encoding](https://developer.pingidentity.com/pingone-api/platform/reference/password-encoding.html)を参照のこと。

例えば、SHA256でソルト処理されたパスワードハッシュを使用している場合、パスワード列の形式は以下の例の通りです：

```
{SSHA256}HSj1oiAFr6wGlPm0hw52iYx6fwQgmgKUsW4Ty6Z0XvoxMjQwNWU4MDBiYmI4ZTNhMzg1YzNiYzAxYjQ3Nzk0NcKgCg==
```

### PingOneにWorker Appを作成する

まだ Worker Appを作成していない場合は、以下の手順で作成します。
すでに作成済みの場合は、Client IDとClient Secret、Environment IDを控えます。

> [!NOTE]
> Worker Appは、Identity Data Adminの権限が必要です。

1. 「Connections」タブをクリックします。
2. 「+ Application」をクリックします。
3. 「Worker」を選択し、「Configure」をクリックします。
4. 名前と説明を入力し、「Save and Close」をクリックします。
5. アプリケーションの一覧に作成したアプリが表示されます。名前のすぐ下に「Client ID」が表示されているので、これを控えておいてください。
6. 新しいアプリケーションを展開し、鉛筆アイコンをクリックします。
7. 「Roles」タブで、使用するPopulation（ポピュレーション）に対して「Identity Data Admin」のロールが割り当てられていることを確認します。もし表示されていない場合は、アプリケーションを作成したユーザーにその権限がないためです。別の管理者がログインして、このロールを割り当てる必要があります。
8. 「Configuration」タブで、「Environment ID」と「Client Secret」を表示して控えておいてください。

### Population IDの取得

1. 左側のサイドバーで「Identities」をクリックし、次に「Populations」をクリックします。
2. ユーザーを追加したいポピュレーションの横にある展開ボタンをクリックし、「Population ID」を控えておきます。

## ツールの実行

必要な情報が揃ったら、以下のようにコマンドを実行します。

```sh
nix run github:cloudnative-co/pingone-user-import-tool/flakes -- \
    --csvFile <filename> \
    --environmentId <environmentid> \
    --populationId <populationid> \
    --clientId <clientid> \
    --clientSecret <clientsecret>
```

> [!NOTE]
> リージョンがUSではない場合は、`--authUri`と`--platformUri`オプションを使って、リージョンを指定します。
> 例えば、アジアリージョンの場合は、`--authUri auth.pingone.asia --platformUri api.pingone.asia` とします。

- ツールの実行が終了すると、結果の要約と失敗の有無が表示されます。失敗がなければ、ユーザーはPingOneにインポートされています。
- エラーが発生した場合、インポートに失敗したユーザーの情報を記録した `rejects.csv` という新しいCSVファイルが作成されます。
    - また、失敗の原因を確認するためのログファイルが作業ディレクトリに生成されます（`user-import-tool.log`）。
- 認証情報の誤りやネットワーク接続の問題でない場合、主な失敗の原因はデータの不備（電話番号やメールの形式、パスワードポリシー違反など）です。
- `rejects.csv` 内のデータを修正して保存し、再度そのファイルを指定して上記のコマンドを実行してください。
- すべてのユーザーがインポートされるまで、手順を繰り返します。

