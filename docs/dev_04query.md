# 目次

- [はじめに](./dev_00.md)
- [ディメンショナルモデリングについて](./dev_01dim.md)
- [BigQuery x ディメンショナルモデリング](./dev_02bigquery.md)
- [BigQuery x dbt x ディメンショナルモデリング](./dev_03dbt.md)
- [実際に使ってみる](./dev_04query.md)
- [Tips: dbt 開発を快適にする](./dev_05dbt_tips.md)
- [Next Step](./dev_06next_step.md)

# 実際に使ってみる

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
