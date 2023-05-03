# 目次

- [はじめに](./dev_00.md)
- [ディメンショナルモデリングについて](./dev_01dim.md)
- [BigQuery x ディメンショナルモデリング](./dev_02bigquery.md)
- [BigQuery x dbt x ディメンショナルモデリング](./dev_03dbt.md)
- [実際に使ってみる](./dev_04query.md)
- [Tips: dbt 開発を快適にする](./dev_05dbt_tips.md)
- [Next Step](./dev_06next_step.md)

# Tips: dbt 開発を快適にする

ここまでで、ガッと dbt で ディメンショナルモデリングをする方法を紹介してきましたが、さらに linter やドキュメントについての設定を加えるとより dbt 開発が快適になります

## sqlfluff による lint 

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

## dbt docs generate によるドキュメント作成

ドキュメントの生成も行いましょう。dbt にはドキュメントの生成を補助する機能がついているので活用します

```
$ poetry run dbt docs generate
$ poetry run dbt docs serve # localhost:8080 でブラウザ経由の GUI からドキュメントを確認できる
```
