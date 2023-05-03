# 目次

- [はじめに](./dev_00.md)
- [ディメンショナルモデリングについて](./dev_01dim.md)
- [BigQuery x ディメンショナルモデリング](./dev_02bigquery.md)
- [BigQuery x dbt x ディメンショナルモデリング](./dev_03dbt.md)
- [実際に使ってみる](./dev_04query.md)
- [Tips: dbt 開発を快適にする](./dev_05dbt_tips.md)
- [Next Step](./dev_06next_step.md)

# BigQuery x ディメンショナルモデリング

物は試しということで [BigQuery](https://cloud.google.com/bigquery?hl=ja) にある [架空のeコマース衣料品サイトのデータセット `theLook eCommerce`](https://console.cloud.google.com/marketplace/product/bigquery-public-data/thelook-ecommerce) を用いてデータモデリングをしてみます。

今回は以下の要件を念頭にこのデータセットをディメンショナルモデリングしてみます。

> 「20代のアクセサリ購入について、購入数と金額が知りたい」

## よくわからないのでとりあえずクエリしてみる

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

```sql
-- fc_order_item
SELECT 
  count(*)
FROM
  `bigquery-public-data.thelook_ecommerce.order_items`

-- 181106
```

なんとなくこのくらいの規模感であればテーブルをよしなに JOIN して終わりな気もしますが、
今回はこの例をディメンショナルモデリングで進めていこうと思います
