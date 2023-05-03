## 動機

> おーい磯野ー！データ分析しようぜ！

春の暖かさが近付くこの頃、データ分析の機運の高まりを感じます。

データ分析とはサービスなどに蓄積されたDBやログなどのデータを解析することである、サービス品質の向上や新しいビジネスモデルの立案を行うための手段の一つです

データ分析においては、様々な形に蓄積されたデータを分析したい形に加工するプロセスがその比重を大きく占めており

1. Event Sourcing よろしく全てのログデータを SSOT としてそのまま分析にかける方法
2. DWH (data ware house) へ一旦全てのデータを正規化しつつ保存し、正規化されたモデルを組み合わせることで効率的にクエリを作る方法

などいろいろな方針がありますが、今回は 2. の方針をとりつつ、ディメンショナルモデリングという手法を考えます。

## ディメンショナルモデリングについて

ディメンショナルモデリングとは、

- 調べたい数字を持ったファクトテーブル
- ファクトテーブルの各要素について説明を行うためのディメンションテーブル

の２種類のテーブルにデータを正規化、これら組み合わせることでデータ分析を行う手法です

例えば、ソーシャルゲームの分析をするとして

>「ガチャについて、特定のガチャイベントのユーザごとのガチャのプレイ回数を調べたい」

みたいな要件をディメンショナルモデリングで考えると以下のようなディメンションとファクトを考えることができます。

- ファクト: ガチャ
- ディメンション: ガチャイベント
- ディメンション: ユーザ

SQLに慣れた形にとっては以下のように考えるとわかりやすいかもしれません。

```sql
-- fc_gacha はガチャ結果のファクトテーブル
-- dm_gacha_event はガチャイベントのテーブル
-- dm_user はユーザのテーブル

SELECT 
  dm_user.id, count(distinct fc_gacha.id) as gacha_play_count
FROM 
  fc_gacha
JOIN
  dm_gacha_event ON fc_gacha.dm_gacha_event.gacha_event_id = dm_gacha_event.id
JOIN 
  dm_user ON fc_gacha.user_id = dm_user.id
WHERE
  dm_gacha_event.id = "2023_04_roki_birthday_gacha"
GROUP BY
  dm_user.id
```

またファクト同士の結合を用いて分析を行うこともでき、例えば

>「ガチャについて、課金層を絞って特定のガチャイベントのガチャのプレイ回数を調べたい」

みたいな要件であれば以下のように考えることができます

- ファクト: ガチャ
- ファクト: ユーザの月間課金量
- ディメンション: ガチャイベント
- ディメンション: ユーザ

```sql
-- fc_gacha はガチャ結果のファクトテーブル
-- fc_user_monthly_charge はユーザ課金額のファクトテーブル
-- dm_gacha_event はガチャイベントのテーブル
-- dm_user はユーザのテーブル

SELECT
  dm_user.id, count(distinct fc_gacha.id) as gacha_play_count
FROM
  fc_gacha
JOIN 
  fc_user_monthly_charge ON fc_user_monthly_charge.user_id = fc_gacha.user_id
JOIN
  dm_gacha_event ON fc_gacha.dm_gacha_event.gacha_event_id = dm_gacha_event.id
JOIN 
  dm_user ON fc_gacha.user_id = dm_user.id
WHERE
  dm_gacha_event.id = "2023_04_roki_birthday_gacha" AND
  fc_user_monthly_charge.year_month = "202304" AND 
  fc_user_monthly_charge.charge_amount > 0 AND 
  fc_user_monthly_charge.charge_amount < 10000
GROUP BY
  dm_user.id
```

ディメンショナルモデリングのメリットとしては、データ絞り込みなどが見やすくなり、また正規化された中間テーブルをベースに分析を進めることで実装者ごとの分析結果のぶれを軽減できることが挙げられます

一方でディメンショナルモデリングのしんどいところとしては、ありとあらゆるデータを繋ぎこんで、全ての因果を解き明かしたい (**ほとんどは相関にすぎません**) 場合などに、テーブルの結合数が素晴らしいことになったり、適切なクエリ設計ができずに激重 Tableau / Looker が爆誕して非難轟轟になったり、というものが挙げられます。

また別のしんどいところとしては、ディメンショナルモデリングではファクトに対してディメンションが原則として one to one / many to one の関係であることが求められる、というものが挙げられます。例えば、EC サイトの商品をファクトとした `fc_shop_item` を考えます。この時商品に複数タグがつけられるとしてそれを `dm_shop_item_tag` とすると、 `fc_shop_item` と `dm_shop_item_tag` は原則として結びつけるのが困難です。解決方法の例としては以下のような方針が考えられます。

1. `fc_shop_item_with_tag` を作って `dm_shop_item_tag` を one to one で結びつける (代わりに `fc_shop_item_with_tag` は商品IDに対して複数レコードを持つ)
2. `fc_shop_item` に対してブリッジテーブル `bg_shop_item_tag_group` を作り `fc_shop_item` と `bg_shop_item_tag_group` を many to one に結んで `bg_shop_item_tag_group` と `dm_shop_item_tag` を one to many で結びつける
3. (タグの中身ではなくタグ数だけを考えたいのであれば) `dm_shop_item_tag_summary` のような商品IDに対して one to one になるようなディメンションを作り、 one to one で結びつける

参考

- ブリッジテーブルについて : https://bigbear.ai/blog/bridge-tables-deep-dive/

## BigQuery のサンプルデータセットを使ってディメンショナルモデリングを設計してみる

物は試しということで [BigQuery](https://cloud.google.com/bigquery?hl=ja) のサンプルデータセットを用いてデータモデリングの真似事をしてみます。

まずは自前で BigQuery を用意し、エクスプローラの追加リンク > `公開データセット` > `theLook eCommerce` を選択します。

`theLook eCommerce` は架空のeコマース衣料品サイトの情報が入っています。
今回はこのデータセットを以下の要件を念頭にディメンショナルモデリングしてみます。

> 「20代のアクセサリ購入について、購入数と金額が知りたい」

### よくわからないのでとりあえずえーいしてみる

`theLook eCommerce` のことはよくわからないので、とりあえずクエリしてみてそこからデータモデリングの方針を立ててみます

今回の絞り込み要件 (`dm`) と抽出したい数字 (`fc`) は以下の通りなのでそれぞれサンプルのクエリを作ってみます

- `dm_user`: 購入ユーザの年齢 => `users` テーブルを見れば良さそう
- `dm_product`: 購入アイテムのカテゴリ => `products` テーブルを見れば良さそう
- `fc_order_item`: 購入数と購入金額 => `order_items` テーブルを見れば良さそう

```sql
-- dm_user
SELECT
 count(*)
FROM
  `bigquery-public-data.thelook_ecommerce.users`
WHERE 
  age >= 20 AND 
  age < 30
LIMIT 1000

-- 16871
```

```sql
-- dm_product
SELECT 
  count(*)
FROM
  `bigquery-public-data.thelook_ecommerce.products`
WHERE 
  category = "Accessories"
   
-- 1559
-- NOTE: 
-- category =
--   [Swim, Jeans, Pants, Socks, Active, Shorts, Sweaters, Underwear,
--    Accessories, Tops & Tees, Sleep & Lounge, Outerwear & Coats, Suits & Sport Coats, 
--    Fashion Hoodies & Sweatshirts, Plus, Suits, Skirts, Dresses, Leggings, Intimates, 
--    Maternity, Clothing Sets, Pants & Capris, Socks & Hosiery, Blazers & Jackets, Jumpsuits & Rompers]
```

```
-- fc_order_item
SELECT 
  count(*)
FROM
  `bigquery-public-data.thelook_ecommerce.order_items`

-- 181106
```

なんとなくこのくらいの規模感であればテーブルをよしなに JOIN して終わりな気もしますが、
この例をディメンショナルモデリングで進めていこうと思います

## dbt を使ってディメンショナルモデリングをやってみる

### 環境構築

今回は [dbt](https://docs.getdbt.com/) を利用して BigQuery のデータをディメンショナルモデリングしてみます

dbt などのパッケージは python 経由で install できるので、良い感じに poetry で管理します

```
$ poetry init
$ poetry add dbt-core dbt-bigquery
$ poetry add -D sqlfluff
```

dbt がインストールできたら、dbt project を作成します。Google Cloud の認証などが必要になるため、適宜入力を行い、`gcloud auth login` `gcloud config set project <project-id>` などを行なって Google Cloud との疎通を行います

```
$ gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/bigquery,\
https://www.googleapis.com/auth/drive.readonly,\
https://www.googleapis.com/auth/iam.test
$ poetry run dbt init dbt_github --profiles-dir .
```

また、dbt の開発に便利なツールである [dbt-utils](https://github.com/dbt-labs/dbt-utils) も入れてしまいましょう。`dbt_github/packages.yaml` に以下を記述し `poetry run dbt deps` を実行します

```
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.0
```

ここまでのいくつかのコマンドは繰り返しが多く、覚えるのも面倒なので Makefile にまとめます

```makefile
local_auth:
	gcloud auth application-default login \
	  --scopes=https://www.googleapis.com/auth/bigquery,\
	https://www.googleapis.com/auth/drive.readonly,\
	https://www.googleapis.com/auth/iam.test

deps:
	poetry run dbt deps

# BQ 上に定義したモデルを作成
run:
	poetry run dbt run

# 定義したモデルのテスト
test:
	poetry run dbt test
```

ここまででディレクトリ構成は大まかに次のようになります

```
❯ tree .
.
├── dbt_github # dbt 本体
│   ├── Makefile
│   ├── README.md
│   ├── analyses
│   ├── dbt_packages
│   │   └── dbt_utils
│   ├── dbt_project.yml
│   ├── logs # dbt の実行ログ
│   ├── macros
│   ├── models
│   │   └── example
│   │       ├── my_first_dbt_model.sql
│   │       ├── my_second_dbt_model.sql
│   │       └── schema.yml
│   ├── packages.yml
│   ├── profiles.yml # gcp の接続先などが書かれた設定ファイル
│   ├── seeds
│   ├── snapshots
│   └── tests
├── docs
├── poetry.lock
└── pyproject.toml

```

参考:
- dbt x BigQuery の環境構築について: https://docs.getdbt.com/reference/warehouse-setups/bigquery-setup
- dbt-utils について: https://hub.getdbt.com/dbt-labs/dbt_utils/latest/
- dbt を用いてディメンショナルモデリングするサンプル: https://github.com/Data-Engineer-Camp/dbt-dimensional-modelling

### モデルの定義

環境構築が一通り完了したので、いよいよファクトテーブルやディメンショナルテーブルをそれぞれ書いていきます。

参考:
- dbt を用いてディメンショナルモデリングするサンプル: https://github.com/Data-Engineer-Camp/dbt-dimensional-modelling
- dbt を用いてデータモデリングするガイド: https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview

#### `staging`

では早速 `dm_user` などを定義していこう、ということになるのが自然です

しかしdbt 的には、生データを加工するレイヤー (staging モデル) とディメンションやファクトを定義するレイヤーを分けて欲しそうで、特に「生データを加工するレイヤー」を `models/staging` に書いて欲しいようなので、それに合わせます

具体的には以下のような定義を `models/staging/thelookec/stg_thelookec__users.sql` などに書いていきます

```sql
with

source as (

  select * from {{ source('thelookec','users') }}

)

select
  id,
  first_name,
  last_name,
  age
from
  source
```

元の `users` テーブルの情報は `models/staging/thelookec/_thelookec__sources.yml` に書きます

```yaml
version: 2

sources:
  - name: thelookec
    database: bigquery-public-data
    schema: thelook_ecommerce
    description: >-
      Fictitious E-Commerce Dataset
      by look team
    tables:
      - name: users
        description: ユーザ情報
```

作成した staging モデル `stg_thelookec__users` の定義などは `models/staging/thelookec/_thelookec__models.yml` に書きます。
staging モデルに書き出す段階で、enum などの書き換えを行なっておくことで後のディメンションやファクトの構築が楽になるかもしれません

```yaml
version: 2

models:
  - name: stg_thelookec__users
    description: ユーザ情報
    config:
      materialized: view
      sort: id
    columns:
      - name: id
        description: ユーザID (Primary Key)
        tests:
          - unique
          - not_null
      - name: first_name
        tests:
          - not_null
      - name: last_name
        tests:
          - not_null
      - name: age
        tests:
          - not_null
```

同様の対応を `product`, `order_items` についても行なっていきます

参考: 
- dbt を用いてデータモデリングするガイド: https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview
- dbt を用いてディメンショナルモデリングするサンプル: https://github.com/Data-Engineer-Camp/dbt-dimensional-modelling/blob/main/adventureworks/models/marts/dim_address.sql

#### `marts`

`staging` で作業用のモデルが準備できたので、いよいよディメンションやファクトの定義を `models/marts` 以下で行います

`dm_user.sql`

```sql
with

user as (

  select * from {{ ref('stg_thelookec__users') }}

)

select
  id,
  first_name,
  last_name,
  age
from
  user
```

`dm_user.yml`

```yml
version: 2

models:
  - name: dm_user
    description: ユーザ情報
    config:
      materialized: view
      sort: id
    columns:
      - name: id
        description: ユーザID (Primary Key)
        tests:
          - unique
          - not_null
      - name: first_name
        tests:
          - not_null
      - name: last_name
        tests:
          - not_null
      - name: age
        tests:
          - not_null
```

同様の対応を `dm_product`, `fc_order_item` についても行なっていきます

## 実際に使ってみる

定義をできたところで、実際にテーブル作成 + テストまで行いましょう

```
$ make run
$ make test
```

テストまで正常に完了したら、 BigQuery で元々のお題である「20代のアクセサリ購入について、購入数と金額が知りたい」をクエリしてみましょう

```sql
SELECT 
  SUM(fc_order_item.sale_price) as earning, 
  COUNT(distinct fc_order_item.id) as order_item_count
FROM 
  `meguru-playground-dev.dbt_thelookec.fc_order_item` as fc_order_item
JOIN 
  `meguru-playground-dev.dbt_thelookec.dm_user` as dm_user ON  fc_order_item.user_id = dm_user.id
JOIN 
  `meguru-playground-dev.dbt_thelookec.dm_product` as dm_product ON  fc_order_item.product_id = dm_product.id
WHERE 
  fc_order_item.status = "Complete" AND -- status をディメンションテーブル (dm_order_status) に切り分けてもよい
  (dm_user.age >= 20 AND dm_user.age < 30) AND
  (dm_product.category = "Accessories")
  
-- earning: 19456.190022945404
-- order_item_count: 465
```

期待通りディメンションで条件付けしてファクトから数字を求めることができました

## dbt 開発を快適にする

ここまでで、ガッと dbt で ディメンショナルモデリングをする方法を紹介してきましたが、さらに linter やドキュメントについての設定を加えるとより dbt 開発が快適になります

### sqlfluff による lint 

SQL のフォーマットが人によって違うのは開発体験がよくないので、linter を導入しましょう

dbt の有名な linter として、 [sqlfluff](https://github.com/sqlfluff/sqlfluff) があるため、こちらを活用します

```
$ poetry add -D sqlfluff
$ poetry add -D sqlfluff-templater-dbt
```

linter の設定は `.sqlfluff`, `.sqlfluffignore` に記載します。
具体的な例は以下の通り

```
# .sqlfluff
[sqlfluff]
dialect = bigquery
templater = dbt

[sqlfluff:templater:jinja]
apply_dbt_builtins = True

[sqlfluff:templater:dbt]
project_dir = ./
profiles_dir = ./
profile = dbt_thelookec
target = dev

[sqlfluff:indentation]
# See https://docs.sqlfluff.com/en/stable/layout.html#configuring-indent-locations
indent_unit = space
tab_space_size = 2
```

```
# .sqlfluffignore
# ignore dbt_packages folder
*dbt_packages/
*target/
*macros/
```

### dbt docs generate によるドキュメント作成

ドキュメントの生成も行いましょう。dbt にはドキュメントの生成を補助する機能がついているので活用します

```
$ poetry run dbt docs generate
$ poetry run dbt docs serve # localhost:8080 でブラウザ経由の GUI からドキュメントを確認できる
```

## Next Step

### `dm_product` のカテゴリのような enum の情報をどのように持たせるか

今回商品ディメンションテーブル `dm_product` のカテゴリ `category` を用いた絞り込みを行いました。
ここで気になるところとして、データ分析を行うユーザはどのようにして `category` に アクセサリ `Accessaries` があることを知ったのか、という点です

実アプリケーションDB上では、おそらくこのカテゴリはマスタテーブル `master_product_categories` で管理されていることは容易に想像がつくことだとは思いますが、現状のディメンショナルモデリングではこのマスタテーブルを記述する場所がありません

かといってこのマスタデータを分析者に毎回実アプリケーションのDBを叩いてもらうのも変な話です

この解決方法として現状パッと思いついているのは以下の2通りです

1. マスタの定義だけは、ディメンショナルモデリングではなく、別の解決方法を用いてモデリングし、分析者に別クエリを実行してもらう
2. 十分にマスタの数が少なく変更が少ないのであれば、 enum としてドキュメント化する

### `intermediate` の使い方

ピボットテーブルなどを作成する中間テーブルとして `intermediate` がありますが、今回のサンプルではピボットテーブルや集約などが不要だったので利用しませんでした

一方でこれらの技術は複雑なデータ分析を行うためには必須なため、適切なサンプルプロジェクトを作成して実験してみたいところがあります

(~~集約したはいいものの XXX でフィルタリングしなきゃやだ！とかなったときにどうするんだろう~~)

参考:
- dbt における `intermediate` についての説明: https://docs.getdbt.com/guides/best-practices/how-we-structure/3-intermediate

### ドキュメントの書きどころ

dbt にはいくつもの中間レイヤーを用意でき、またそれぞれのレイヤーのモデルに対して description を追加することができます。

一方で中間レイヤーの定義情報を使い回すことが難しいため、たらい回しになっているカラムの description を統一で管理することができません。

このため、ドキュメントのばらつきを抑えるにはどこかのドキュメントを諦める、などの対応が必要になります

あるいは別の選択肢として `staging` や `intermediate` を `marts` の定義 sql の中にハードコードしてしまう、という選択肢もあります。
プロダクトの規模や分析したい複雑性さに応じて使い分けるのが良いのかもしれません

参考:
- dbt で `staging` を `marts` 内部で定義する例: https://github.com/Data-Engineer-Camp/dbt-dimensional-modelling
