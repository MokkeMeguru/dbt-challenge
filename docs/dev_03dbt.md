# 目次

- [はじめに](./dev_00.md)
- [ディメンショナルモデリングについて](./dev_01dim.md)
- [BigQuery x ディメンショナルモデリング](./dev_02bigquery.md)
- [BigQuery x dbt x ディメンショナルモデリング](./dev_03dbt.md)
- [実際に使ってみる](./dev_04query.md)
- [Tips: dbt 開発を快適にする](./dev_05dbt_tips.md)
- [Next Step](./dev_06next_step.md)

# BigQuery x dbt x ディメンショナルモデリング

今回は [dbt](https://docs.getdbt.com/) を利用して BigQuery のデータをディメンショナルモデリングしてみます

## 環境構築

dbt は python 経由で install できるので、良い感じに [poetry](https://github.com/python-poetry/poetry) で管理します

```
$ poetry init
$ poetry add dbt-core dbt-bigquery
$ poetry add -D sqlfluff
```

dbt がインストールできたら、dbt project を作成します。

まずは BigQuery を使う都合上、Google Cloud の認証を行い、その上で dbt project を作成します。

```
$ gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/bigquery,\
https://www.googleapis.com/auth/drive.readonly,\
https://www.googleapis.com/auth/iam.test
$ poetry run dbt init dbt_thelookec --profiles-dir .
```

また、dbt の開発に便利なツールである [dbt-utils](https://github.com/dbt-labs/dbt-utils) も入れてしまいましょう。`dbt_github/packages.yaml` に以下を記述し `poetry run dbt deps` を実行します

```yaml
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

## モデルの定義

環境構築が一通り完了したので、いよいよファクトテーブルやディメンショナルテーブルをそれぞれ書いていきます。

参考:
- dbt を用いてディメンショナルモデリングするサンプル: https://github.com/Data-Engineer-Camp/dbt-dimensional-modelling
- dbt を用いてデータモデリングするガイド: https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview

### `staging`

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
    description: Fictitious E-Commerce Dataset
    tables:
      - name: users
        description: ユーザ情報
```

作成した staging モデル `stg_thelookec__users` の定義などは `models/staging/thelookec/_thelookec__models.yml` に書きます。

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

### `marts`

`staging` で中間モデルが準備できたので、いよいよディメンションやファクトの定義を `models/marts` 以下で行います

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

