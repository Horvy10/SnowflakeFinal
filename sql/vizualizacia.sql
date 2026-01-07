Tržby podľa kategórie produktu :

SELECT
  i.category,
  SUM(f.ss_net_paid) AS total_revenue
FROM FACT_STORE_SALES f
JOIN DIM_ITEM i ON f.item_sk = i.item_sk
GROUP BY i.category
ORDER BY total_revenue DESC;




Top 10 obchodov podľa tržieb : 

SELECT
  s.store_name,
  SUM(f.ss_net_paid) AS total_revenue
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 10;



Najaktívnejšie obchody podľa počtu transakcií za rok 2000:

SELECT
  s.store_name,
  COUNT(*) AS transactions_count
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
JOIN DIM_DATE d  ON f.date_sk = d.date_sk
WHERE d.year = 2000
GROUP BY s.store_name
ORDER BY transactions_count DESC
LIMIT 20;




Aktivita zákazníkov podľa roku narodenia:

SELECT
  c.birth_year,
  COUNT(*) AS sales_count
FROM FACT_STORE_SALES f
JOIN DIM_CUSTOMER c ON f.customer_sk = c.customer_sk
GROUP BY c.birth_year
ORDER BY c.birth_year;




Priemerný počet položiek na transakciu podľa obchod a kategórie:

SELECT
  s.store_name,
  i.category,
  AVG(f.ss_quantity) AS avg_items_per_sale
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
JOIN DIM_ITEM i  ON f.item_sk = i.item_sk
GROUP BY s.store_name, i.category
ORDER BY avg_items_per_sale DESC;



TOP Kategórie v jednotlivých mestách podľa počtu transakcií:


SELECT
  s.city,
  i.category,
  COUNT(*) AS transactions_count
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
JOIN DIM_ITEM i  ON f.item_sk = i.item_sk
GROUP BY s.city, i.category
ORDER BY transactions_count DESC
LIMIT 50;
