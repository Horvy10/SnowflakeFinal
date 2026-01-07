# **ELT proces datasetu TPC-DS (Retail Sales) v Snowflake**

Tento repozitár obsahuje implementáciu **ELT procesu v Snowflake** nad datasetom **TPC-DS 10TB Managed Iceberg** (Snowflake Marketplace). Projekt sa zameriava na analýzu maloobchodného predaja (store sales) a správania zákazníkov naprieč obchodmi, produktmi, časom a geografickými lokalitami.

Výsledkom je **dátový sklad so schémou hviezdy (Star Schema)**, faktová tabuľka s **window functions** a minimálne **5 vizualizácií** vytvorených v Snowflake Dashboarde.

---

## **1. Úvod a popis zdrojových dát**

### Prečo TPC-DS
- dataset je dostupný v **Snowflake Marketplace**,
- simuluje realistický retailový biznis proces,
- má bohatý model vhodný na návrh DWH (Kimball).

### Použité zdrojové tabuľky (Marketplace)
- `DATE_DIM` – kalendár (dátum, rok, mesiac, štvrťrok, deň v týždni…)
- `ITEM` – produktové údaje (kategória, trieda, značka…)
- `STORE` – obchody a geografia (mesto, štát…)
- `CUSTOMER` – demografia zákazníkov
- `STORE_SALES` – transakčné údaje o predaji v predajni

**Marketplace databáza/schéma:**
```sql
TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG
```

### ERD pôvodného modelu
ERD (relačný model zdrojových tabuliek) je v `/img/erd.png`.

---

## **2. Návrh dimenzionálneho modelu (Star Schema)**

Navrhnutý model obsahuje 1 faktovú tabuľku a 4 dimenzie:

### Dimenzie
- `DIM_DATE` (SCD Typ 0) – kalendár (statické atribúty)
- `DIM_ITEM` (SCD Typ 0) – produktové atribúty (statické)
- `DIM_STORE` (SCD Typ 0) – obchod + geografia (statické)
- `DIM_CUSTOMER` (SCD Typ 1) – demografia (aktualizácia bez histórie)

### Faktová tabuľka
- `FACT_STORE_SALES`
  - FK: `date_sk`, `item_sk`, `store_sk`, `customer_sk`
  - metriky: `ss_quantity`, `ss_sales_price`, `ss_net_paid`
  - analytické stĺpce cez **window functions** (povinné v zadaní)

Star Schema diagram je v `/img/star_schema.png`.

---

## **3. ELT proces v Snowflake**

### **3.1 Extract → staging tabuľky (CTAS)**
Dáta sú extrahované z Marketplace do vlastnej DB `BOA_DB` do schémy `PROJEKT_STAGING`.

```sql
USE DATABASE BOA_DB;
CREATE SCHEMA IF NOT EXISTS PROJEKT_STAGING;
USE SCHEMA PROJEKT_STAGING;

-- DATE: od roku 2000 (bez limitu)
CREATE OR REPLACE TABLE DATE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.DATE_DIM
WHERE d_year >= 2000;

-- ITEM
CREATE OR REPLACE TABLE ITEM_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.ITEM;

-- STORE
CREATE OR REPLACE TABLE STORE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.STORE;

-- CUSTOMER
CREATE OR REPLACE TABLE CUSTOMER_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.CUSTOMER;

-- STORE_SALES: synchronizované s DATE_STAGING (rok >= 2000) + limit kvôli objemu
CREATE OR REPLACE TABLE STORE_SALES_STAGING AS
SELECT ss.*
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.STORE_SALES ss
JOIN DATE_STAGING d
  ON ss.ss_sold_date_sk = d.d_date_sk
WHERE ss.ss_sold_date_sk IS NOT NULL
  AND ss.ss_item_sk IS NOT NULL
  AND ss.ss_store_sk IS NOT NULL
  AND ss.ss_customer_sk IS NOT NULL
LIMIT 100000;
```

---

### **3.2 Load/Transform → dimenzie + fakt (Star Schema)**
Finálne tabuľky sú vytvorené v schéme `PROJEKT_DWH`.

```sql
USE DATABASE BOA_DB;
CREATE SCHEMA IF NOT EXISTS PROJEKT_DWH;
USE SCHEMA PROJEKT_DWH;
```

#### DIM_DATE
```sql
CREATE OR REPLACE TABLE DIM_DATE AS
SELECT
  d_date_sk  AS date_sk,
  d_date     AS date,
  d_year     AS year,
  d_moy      AS month,
  d_qoy      AS quarter,
  d_day_name AS day_name
FROM BOA_DB.PROJEKT_STAGING.DATE_STAGING;
```

#### DIM_ITEM
```sql
CREATE OR REPLACE TABLE DIM_ITEM AS
SELECT
  i_item_sk   AS item_sk,
  i_item_id   AS item_id,
  i_item_desc AS item_desc,
  i_category  AS category,
  i_class     AS class,
  i_brand     AS brand
FROM BOA_DB.PROJEKT_STAGING.ITEM_STAGING;
```

#### DIM_STORE
```sql
CREATE OR REPLACE TABLE DIM_STORE AS
SELECT
  s_store_sk   AS store_sk,
  s_store_id   AS store_id,
  s_store_name AS store_name,
  s_city       AS city,
  s_state      AS state,
  s_country    AS country
FROM BOA_DB.PROJEKT_STAGING.STORE_STAGING;
```

#### DIM_CUSTOMER
```sql
CREATE OR REPLACE TABLE DIM_CUSTOMER AS
SELECT
  c_customer_sk      AS customer_sk,
  c_first_name       AS first_name,
  c_last_name        AS last_name,
  c_gender           AS gender,
  c_birth_year       AS birth_year,
  c_current_country  AS current_country
FROM BOA_DB.PROJEKT_STAGING.CUSTOMER_STAGING;
```

---

## **3.3 Faktová tabuľka s window functions (povinné)**

```sql
CREATE OR REPLACE TABLE FACT_STORE_SALES AS
SELECT
  -- 1) ROW_NUMBER(): technický primárny kľúč (surrogate key) faktovej tabuľky
  ROW_NUMBER() OVER (
    ORDER BY ss.ss_sold_date_sk, ss.ss_store_sk, ss.ss_item_sk, ss.ss_customer_sk
  ) AS ss_id,

  -- FK na dimenzie
  d.date_sk     AS date_sk,
  i.item_sk     AS item_sk,
  s.store_sk    AS store_sk,
  c.customer_sk AS customer_sk,

  -- metriky
  ss.ss_quantity     AS ss_quantity,
  ss.ss_net_paid     AS ss_net_paid,
  ss.ss_sales_price  AS ss_sales_price,

  -- 2) SUM() OVER(): kumulatívne tržby obchodu v čase (running revenue)
  SUM(ss.ss_net_paid) OVER (
    PARTITION BY ss.ss_store_sk
    ORDER BY ss.ss_sold_date_sk
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS running_store_revenue,

  -- 3) RANK() OVER(): poradie predaja v rámci obchodu podľa výšky platby (top sales)
  RANK() OVER (
    PARTITION BY ss.ss_store_sk
    ORDER BY ss.ss_net_paid DESC
  ) AS sale_rank_in_store,

  -- 4) LAG() OVER(): predchádzajúca hodnota platby zákazníka (customer purchase history)
  LAG(ss.ss_net_paid) OVER (
    PARTITION BY ss.ss_customer_sk
    ORDER BY ss.ss_sold_date_sk
  ) AS prev_customer_payment

FROM BOA_DB.PROJEKT_STAGING.STORE_SALES_STAGING ss
JOIN DIM_DATE d       ON ss.ss_sold_date_sk = d.date_sk
JOIN DIM_ITEM i       ON ss.ss_item_sk = i.item_sk
JOIN DIM_STORE s      ON ss.ss_store_sk = s.store_sk
JOIN DIM_CUSTOMER c   ON ss.ss_customer_sk = c.customer_sk;
```

---

## **4. Vizualizácie (min. 5) – SQL + interpretácia**

> Vizualizácie boli vytvorené v Snowflake: **Worksheet → Chart → Add to Dashboard**.  
> Screenshot dashboardu je v `/img/dashboard.png`.

---

### **Graf 1: Najaktívnejšie obchody podľa počtu transakcií (Top 10)**
**Čo ukazuje:** ktoré predajne majú najvyššiu aktivitu (počet transakcií).

```sql
SELECT
  s.store_name,
  COUNT(*) AS transactions_count
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
GROUP BY s.store_name
ORDER BY transactions_count DESC
LIMIT 10;
```

---

### **Graf 2: Počet transakcií podľa dňa v týždni a obchodu**
**Čo ukazuje:** porovnanie aktivity obchodov počas týždňa (napr. štvrtok vs. iné dni).

```sql
SELECT
  d.day_name,
  s.store_name,
  COUNT(*) AS transactions_count
FROM FACT_STORE_SALES f
JOIN DIM_DATE d  ON f.date_sk = d.date_sk
JOIN DIM_STORE s ON f.store_sk = s.store_sk
GROUP BY d.day_name, s.store_name
ORDER BY d.day_name, transactions_count DESC;
```

---

### **Graf 3: Najaktívnejšie mestá podľa počtu transakcií (Top 20)**
**Čo ukazuje:** mestá s najväčším počtom transakcií (regionálna aktivita).

```sql
SELECT
  s.city,
  COUNT(*) AS transactions_count
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
GROUP BY s.city
ORDER BY transactions_count DESC
LIMIT 20;
```

---

### **Graf 4: Počet transakcií podľa mesta a kategórie (Top 50 kombinácií)**
**Čo ukazuje:** kombinácie mesto–kategória s najvyššou aktivitou (regionálne preferencie).

```sql
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
```

---

### **Graf 5: Veľkosť nákupného košíka podľa obchodu a kategórie**
**Čo ukazuje:** priemerný počet kusov na transakciu (basket size) v jednotlivých obchodoch a kategóriách.

```sql
SELECT
  s.store_name,
  i.category,
  AVG(f.ss_quantity) AS avg_items_per_sale
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
JOIN DIM_ITEM i  ON f.item_sk = i.item_sk
GROUP BY s.store_name, i.category
ORDER BY avg_items_per_sale DESC;
```

---

### **Graf 6 (voliteľný): Kumulatívne tržby obchodu (running revenue)**
**Čo ukazuje:** rast tržieb v čase pre obchody pomocou window function (running sum).

```sql
SELECT
  s.store_name,
  d.date,
  SUM(f.ss_net_paid) AS daily_revenue,
  SUM(SUM(f.ss_net_paid)) OVER (
    PARTITION BY s.store_name
    ORDER BY d.date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS running_revenue
FROM FACT_STORE_SALES f
JOIN DIM_DATE d  ON f.date_sk = d.date_sk
JOIN DIM_STORE s ON f.store_sk = s.store_sk
GROUP BY s.store_name, d.date
ORDER BY s.store_name, d.date;
```

---

## **5. Štruktúra repozitára**

```
/sql        → ELT skripty (Extract, Transform: DIM/FACT)
/img        → ERD, Star Schema, Dashboard screenshoty
README.md   → dokumentácia projektu
```

---

## **Autor**
**Doplň svoje meno a priezvisko**
