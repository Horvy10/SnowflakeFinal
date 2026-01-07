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
<p align="center">
<img width="500" height="500" alt="erd" src="https://github.com/user-attachments/assets/615dc815-7d7c-455d-a955-a13a978faf3a" />
</p>
<p align="center"><em>Obrázok 1 ERD Model</em></p>


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
  - analytické stĺpce cez **window functions**

<p align="center">
<img width="600" height="500" alt="hviezda" src="https://github.com/user-attachments/assets/d853cae6-3e8b-4f88-89c7-bfc1ef1a15a1" />
</p>
<p align="center"><em>Obrázok 2 Star Schéma</em></p>

---

# 3. ELT proces v Snowflake

ELT proces pozostáva z troch hlavných krokov:

**ELT = Extract – Load – Transform**

- **Extract (Extrahovanie)** – získanie dát zo zdrojového systému  
- **Load (Načítanie)** – uloženie dát do vlastnej databázy v Snowflake  
- **Transform (Transformácia)** – úprava dát, tvorba dimenzií a faktovej tabuľky  

V projekte bol ELT proces realizovaný výhradne pomocou **SQL v Snowflake**.

---

## 3.1 Extract – zdroj dát

Zdrojové dáta pochádzajú zo **Snowflake Marketplace**, konkrétne z datasetu:

**TPC-DS 10TB Managed Iceberg**

Dataset je **read-only**, preto s ním nie je možné priamo pracovať ani ho upravovať.  
Z tohto dôvodu boli dáta extrahované do vlastnej databázy pomocou **CTAS (CREATE TABLE AS SELECT)**.

---

## 3.2 Load – staging tabuľky (CTAS)

Dáta boli načítané do databázy **BOA_DB** do schémy **PROJEKT_STAGING**, ktorá slúži ako staging vrstva.

```sql
CREATE OR REPLACE SCHEMA BOA_DB.PROJEKT_STAGING;
USE SCHEMA BOA_DB.PROJEKT_STAGING;
Vytvorenie staging tabuliek
DATE_STAGING
sql
Kopírovať kód
CREATE OR REPLACE TABLE DATE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.DATE_DIM
WHERE d_year >= 2000;
ITEM_STAGING
sql
Kopírovať kód
CREATE OR REPLACE TABLE ITEM_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.ITEM;
STORE_STAGING
sql
Kopírovať kód
CREATE OR REPLACE TABLE STORE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.STORE;
CUSTOMER_STAGING
sql
Kopírovať kód
CREATE OR REPLACE TABLE CUSTOMER_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.CUSTOMER;
STORE_SALES_STAGING
sql
Kopírovať kód
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
3.3 Transformácia dát
V tejto fáze boli staging tabuľky transformované do dimenzionálneho modelu (Star Schema).
Transformácie zahŕňali:

výber relevantných atribútov

odstránenie NULL hodnôt

tvorbu dimenzií a faktovej tabuľky

použitie window functions

Použité SCD typy:

SCD Type 0 – nemenné dimenzie (date, item, store)

SCD Type 1 – dimenzia customer

3.4 DIM_DATE
Časová dimenzia umožňuje analýzu dát podľa dňa, mesiaca, roka a štvrťroka.

SCD: Type 0 – dátumy sa nemenia

sql
Kopírovať kód
CREATE OR REPLACE TABLE DIM_DATE AS
SELECT
    d_date_sk     AS date_sk,
    d_date        AS date,
    d_year        AS year,
    d_moy         AS month,
    d_qoy         AS quarter,
    d_day_name    AS day_name
FROM DATE_STAGING
WHERE d_date_sk IS NOT NULL;
3.5 DIM_ITEM
Dimenzia produktu obsahuje informácie o položkách predávaných v obchodoch.

SCD: Type 0 – produktové údaje sa nemenia

sql
Kopírovať kód
CREATE OR REPLACE TABLE DIM_ITEM AS
SELECT
    i_item_sk     AS item_sk,
    i_item_id     AS item_id,
    i_item_desc   AS item_desc,
    i_category    AS category,
    i_class       AS class,
    i_brand       AS brand
FROM ITEM_STAGING
WHERE i_item_sk IS NOT NULL;
3.6 DIM_STORE
Geografická dimenzia obchodov.

SCD: Type 0 – obchody sú stabilné

sql
Kopírovať kód
CREATE OR REPLACE TABLE DIM_STORE AS
SELECT
    s_store_sk    AS store_sk,
    s_store_id    AS store_id,
    s_store_name  AS store_name,
    s_city        AS city,
    s_state       AS state,
    s_country     AS country
FROM STORE_STAGING
WHERE s_store_sk IS NOT NULL;
3.7 DIM_CUSTOMER
Dimenzia zákazníkov obsahuje demografické údaje.

SCD: Type 1 – aktualizácia bez histórie

sql
Kopírovať kód
CREATE OR REPLACE TABLE DIM_CUSTOMER AS
SELECT
    c_customer_sk     AS customer_sk,
    c_first_name      AS first_name,
    c_last_name       AS last_name,
    c_birth_year      AS birth_year,
    c_birth_country   AS birth_country,
    c_email_address   AS email_address
FROM CUSTOMER_STAGING
WHERE c_customer_sk IS NOT NULL;
3.8 Faktová tabuľka – FACT_STORE_SALES
Faktová tabuľka prepája všetky dimenzie a obsahuje merateľné hodnoty predaja.

Použité window functions:

ROW_NUMBER() – technický primárny kľúč

SUM() OVER() – kumulatívny obrat obchodu

RANK() – poradie predajov v obchode

LAG() – porovnanie s predchádzajúcim nákupom zákazníka

sql
Kopírovať kód
CREATE OR REPLACE TABLE FACT_STORE_SALES AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY ss.ss_sold_date_sk,
                 ss.ss_store_sk,
                 ss.ss_item_sk,
                 ss.ss_customer_sk
    ) AS ss_id,

    d.date_sk        AS date_sk,
    i.item_sk        AS item_sk,
    s.store_sk       AS store_sk,
    c.customer_sk    AS customer_sk,

    ss.ss_quantity       AS ss_quantity,
    ss.ss_net_paid       AS ss_net_paid,
    ss.ss_sales_price    AS ss_sales_price,

    SUM(ss.ss_net_paid) OVER (
        PARTITION BY ss.ss_store_sk
        ORDER BY ss.ss_sold_date_sk
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_store_revenue,

    RANK() OVER (
        PARTITION BY ss.ss_store_sk
        ORDER BY ss.ss_net_paid DESC
    ) AS sale_rank_in_store,

    LAG(ss.ss_net_paid) OVER (
        PARTITION BY ss.ss_customer_sk
        ORDER BY ss.ss_sold_date_sk
    ) AS prev_customer_payment

FROM STORE_SALES_STAGING ss
JOIN DIM_DATE d ON ss.ss_sold_date_sk = d.date_sk
JOIN DIM_ITEM i ON ss.ss_item_sk = i.item_sk
JOIN DIM_STORE s ON ss.ss_store_sk = s.store_sk
JOIN DIM_CUSTOMER c ON ss.ss_customer_sk = c.customer_sk
WHERE ss.ss_sold_date_sk IS NOT NULL;
---
```
## **4. Vizualizácie**

> Vizualizácie boli vytvorené v Snowflake **Dashboard**.  
<img width="500" height="500" alt="viz1" src="https://github.com/user-attachments/assets/83d9f559-fcb9-4e30-b419-3bad65c9fd89" />
<img width="500" height="500" alt="viz2" src="https://github.com/user-attachments/assets/f73dd3b2-96c4-441d-a313-2fae3312690d" />
<p align="center"><em>Obrázok 3,4 Vizualizácie</em></p>

---
```sql
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
```
---
---


## **Autor**
**Doplň svoje meno a priezvisko**
