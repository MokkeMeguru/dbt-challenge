# 目次

- [はじめに](./dev.md)
- [ディメンショナルモデリングについて](./dev_01dim.md)
- [BigQuery x ディメンショナルモデリング](./dev_02bigquery.md)
- [BigQuery x dbt x ディメンショナルモデリング](./dev_03dbt.md)
- [実際に使ってみる](./dev_04query.md)
- [Tips: dbt 開発を快適にする](./dev_05dbt_tips.md)
- [Next Step](./dev_06next_step.md)

# Next Step
## `dm_product` のカテゴリのような enum の情報をどのように持たせるか

今回商品ディメンションテーブル `dm_product` のカテゴリ `category` を用いた絞り込みを行いました。
ここで気になるところとして、データ分析を行うユーザはどのようにして `category` に アクセサリ `Accessaries` があることを知ったのか、という点です

実アプリケーションDB上では、おそらくこのカテゴリはマスタテーブル `master_product_categories` で管理されていることは容易に想像がつくことだとは思いますが、現状のディメンショナルモデリングではこのマスタテーブルを記述する場所がありません

かといってこのマスタデータを分析者に毎回実アプリケーションのDBを叩いてもらうのも変な話です

この解決方法として現状パッと思いついているのは以下の2通りです

1. マスタの定義だけは、ディメンショナルモデリングではなく、別の解決方法を用いてモデリングし、分析者に別クエリを実行してもらう
2. 十分にマスタの数が少なく変更が少ないのであれば、 enum としてドキュメント化する

## `intermediate` の使い方

ピボットテーブルなどを作成する中間テーブルとして `intermediate` がありますが、今回のサンプルではピボットテーブルや集約などが不要だったので利用しませんでした

一方でこれらの技術は複雑なデータ分析を行うためには必須なため、適切なサンプルプロジェクトを作成して実験してみたいところがあります

(~~集約したはいいものの XXX でフィルタリングしなきゃやだ！とかなったときにどうするんだろう~~)

参考:
- dbt における `intermediate` についての説明: https://docs.getdbt.com/guides/best-practices/how-we-structure/3-intermediate

## ドキュメントの書きどころ

dbt にはいくつもの中間レイヤーを用意でき、またそれぞれのレイヤーのモデルに対して description を追加することができます。

一方で中間レイヤーの定義情報を使い回すことが難しいため、たらい回しになっているカラムの description を統一で管理することができません。

このため、ドキュメントのばらつきを抑えるにはどこかのドキュメントを諦める、などの対応が必要になります

あるいは別の選択肢として `staging` や `intermediate` を `marts` の定義 sql の中にハードコードしてしまう、という選択肢もあります。
プロダクトの規模や分析したい複雑性さに応じて使い分けるのが良いのかもしれません

参考:
- dbt で `staging` を `marts` 内部で定義する例: https://github.com/Data-Engineer-Camp/dbt-dimensional-modelling