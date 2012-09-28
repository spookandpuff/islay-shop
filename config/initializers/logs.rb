ActivityLog.register(:order, OrderLogDecorator, %{
  SELECT
    'order' AS type,
    ols.created_at,
    (SELECT name FROM users WHERE id = ols.creator_id) AS user_name,
    ols.action AS event,
    os.reference || ' - ' || os.name AS name,
    os.id,
    NULL AS parent_id
  FROM order_logs AS ols
  JOIN orders AS os ON os.id = ols.order_id
  ORDER BY ols.created_at DESC
})

ActivityLog.register(:stock, StockLogDecorator, %{
  SELECT
    'stock' AS type,
    sls.created_at,
    (SELECT name FROM users WHERE id = sls.creator_id) AS user_name,
    sls.action AS event,
    (SELECT name FROM products WHERE id = skus.product_id) || ' - ' || skus.short_desc AS name,
    skus.id,
    skus.product_id AS parent_id
  FROM sku_stock_logs AS sls
  JOIN skus ON skus.id = sku_id
  ORDER BY created_at DESC
})

ActivityLog.register(:price_change, PriceLogDecorator, %{
  SELECT
    'price_change' AS type,
    pls.created_at,
    (SELECT name FROM users WHERE id = pls.creator_id) AS user_name,
    'Price update' AS event,
    (SELECT name FROM products WHERE id = skus.product_id) || ' - ' || skus.short_desc AS name,
    skus.id,
    skus.product_id AS parent_id
  FROM sku_price_logs AS pls
  JOIN skus ON skus.id = sku_id
  ORDER BY created_at DESC
})
