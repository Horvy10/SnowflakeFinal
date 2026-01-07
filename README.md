# **ELT proces datasetu TPC-DS v Snowflake**

Tento repozitár obsahuje implementáciu **ELT procesu v Snowflake** nad datasetom **TPC-DS 10TB Managed Iceberg**. 

V projekte sme sa rozhodli vybrať iba päť tabuliek z celého datasetu TPC-DS, ktoré spolu tvoria ucelený a logicky prepojený biznis proces predaja v napríklad kamenných obchodoch a predajniach. Cieľom bolo zjednodušiť dátový model a vytvoriť plnohodnotnú hviezdicovú schému. Vybrané tabuľky pokrývajú kľúčové entity predaje, zákazníci, produkty, obchody a čas,  čo umožňuje vytvoriť plnohodnotnú hviezdicovú schému.

Výsledkom je **dátový sklad s hviezdicovou schémou**, faktová tabuľka s **window functions** a **6 vizualizácií** vytvorenými v Snowflake Dashboarde.

---

## **1. Úvod a popis zdrojových dát**

### Prečo TPC-DS
- dataset je dostupný v **Snowflake Marketplace**,
- simuluje realistický retailový biznis proces,
- vysoká praktickosť,
- schopnosť analyzovať veľké množstvo dát

### Použité zdrojové tabuľky
- `DATE_DIM` – dátum, rok, mesiac, štvrťrok, deň v týždni,
- `ITEM` – produktové údaje (kategória, trieda, značka...)
- `STORE` – obchody a geografia (mesto, štát...)
- `CUSTOMER` – tabuľka zákazníkov(meno,priezvisko...)
- `STORE_SALES` – transakčné údaje o predaji v predajni

**Marketplace databáza:**
```sql
TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG
```
<p align="center">
<img width="500" height="500" alt="erd" src="https://github.com/user-attachments/assets/fc94c624-07f4-472f-8b83-3e1361c72be5" />
</p>
<p align="center"><em>Obrázok 1 ERD Model</em></p>


---

## **2. Návrh dimenzionálneho modelu (Star Schema)**

Navrhnutý model obsahuje 1 faktovú tabuľku a 4 dimenzie:

### Dimenzie
- `DIM_DATE`
- `DIM_ITEM`
- `DIM_STORE`
- `DIM_CUSTOMER`

### Faktová tabuľka
- `FACT_STORE_SALES`
  - FK: `date_sk`, `item_sk`, `store_sk`, `customer_sk`
  - metriky: `ss_quantity`, `ss_sales_price`, `ss_net_paid`
  - window functions

<p align="center">
<img width="500" height="500" alt="hviezda" src="https://github.com/user-attachments/assets/d853cae6-3e8b-4f88-89c7-bfc1ef1a15a1" />
</p>
<p align="center"><em>Obrázok 2 Star Schema</em></p>

---

## 3. ELT proces v Snowflake

ELT proces pozostáva z troch hlavných krokov:

**ELT = Extract – Load – Transform**

- **Extract (Extrahovanie)** – získanie dát zo zdrojového systému  
- **Load (Načítanie)** – uloženie dát do vlastnej databázy v Snowflake  
- **Transform (Transformácia)** – úprava dát, tvorba dimenzií a faktovej tabuľky  

Celý ELT proces bol realizovaný výhradne pomocou **SQL v Snowflake**.

---

### 3.1 Extract – zdroj dát

Zdrojové dáta pochádzajú zo **Snowflake Marketplace**, konkrétne z datasetu:

**TPC-DS 10TB Managed Iceberg**

Dataset je **read-only**, čo znamená, že ho nie je možné priamo upravovať.  
Z tohto dôvodu boli dáta extrahované do vlastnej databázy pomocou príkazu  
**CREATE TABLE AS SELECT**.

---

### 3.2 Load – staging tabuľky

Dáta boli načítané do databázy **BOA_DB** do schémy **PROJEKT_STAGING**, ktorá slúži ako staging vrstva.

```sql
CREATE OR REPLACE SCHEMA BOA_DB.PROJEKT_STAGING;
USE SCHEMA BOA_DB.PROJEKT_STAGING;
```
Vytvorenie staging tabuliek:

**DATE_STAGING**

```sql
CREATE OR REPLACE TABLE DATE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.DATE_DIM
WHERE d_year >= 2000;
```
**ITEM_STAGING**
```sql
CREATE OR REPLACE TABLE ITEM_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.ITEM;
```
**STORE_STAGING**
```sql
CREATE OR REPLACE TABLE STORE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.STORE;
```
**CUSTOMER_STAGING**
```sql
CREATE OR REPLACE TABLE CUSTOMER_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.CUSTOMER;
```
**STORE_SALES_STAGING**
```sql
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

### 3.3 Transform – tvorba dimenzií
V tejto fáze boli staging tabuľky transformované do dimenzionálneho modelu (Star Schema).
Transformácia zahŕňala výber špecifických stĺpcov,kvôli redukovaniu nadbytočných dát, odstránenie NULL hodnôt
a vytvorenie dimenzií so správnym SCD typom.

---

### 3.4 DIM_DATE
Časová dimenzia umožňuje analýzu dát podľa dňa, mesiaca, roka a štvrťroka.
**SCD: Type 0 – dátumy sa nemenia**
```sql
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
```
### 3.5 DIM_ITEM
Dimenzia produktu obsahuje informácie o predávaných položkách.
**SCD: Type 0 – produktové údaje sú nemenné**
```sql
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
```
### 3.6 DIM_STORE
Dimenzia obchodov a ich lokality(štát,mesto,ulica...).
**SCD: Type 0 – obchody sú stabilné**
```sql
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
```

### 3.7 DIM_CUSTOMER
Dimenzia zákazníkov obsahuje základné údaje(meno,priezvisko,email...).
**SCD: Type 1 – aktualizácia bez histórie**
```sql
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
```
### 3.8 FACT_STORE_SALES
Faktová tabuľka prepája všetky dimenzie a obsahuje merateľné hodnoty predaja.
Obsahuje aj window functions, ktoré umožňujú pokročilú analýzu.

Použité window functions:

-ROW_NUMBER() – technický primárny kľúč

-SUM() OVER() – kumulatívny obrat obchodu

-RANK() – poradie predajov v rámci obchodu

-LAG() – porovnanie aktuálneho a predchádzajúceho nákupu zákazníka

```sql
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
```
---
## **4. Vizualizácie**
<p align="center">
<img width="500" height="500" alt="viz1" src="https://github.com/user-attachments/assets/83d9f559-fcb9-4e30-b419-3bad65c9fd89" />
<img width="500" height="500" alt="viz2" src="https://github.com/user-attachments/assets/f73dd3b2-96c4-441d-a313-2fae3312690d" />
</p>
<p align="center"><em>Obrázok 3,4 Vizualizácie</em></p>

---

## Graf 1: Tržby podľa kategórie produktu
```sql
SELECT
  i.category,
  SUM(f.ss_net_paid) AS total_revenue
FROM FACT_STORE_SALES f
JOIN DIM_ITEM i ON f.item_sk = i.item_sk
GROUP BY i.category
ORDER BY total_revenue DESC;
```
Kód slúži na vytvorenie grafu, ktorý vizualizuje celkové tržby podľa produktovej kategórie. Umožňuje rýchlo identifikovať najziskovejšie kategórie.

## Graf 2: Top 10 obchodov podľa tržieb
```sql
SELECT
  s.store_name,
  SUM(f.ss_net_paid) AS total_revenue
FROM FACT_STORE_SALES f
JOIN DIM_STORE s ON f.store_sk = s.store_sk
GROUP BY s.store_name
ORDER BY total_revenue DESC
LIMIT 10;
```
Kód slúži na vytvorenie grafu, ktorý vizualizuje 10 obchodov s najvyššími tržbami. Graf pomáha porovnávať zisk predajní.

## Graf 3: Najaktívnejšie obchody podľa počtu transakcií v roku 2000
```sql
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
```
Kód slúži na vytvorenie grafu, ktorý vizualizuje najaktívnejšie predajne podľa počtu transakcií za rok 2000. Umožňuje sledovať aktivitu a výkonnosť predajní.

## Graf 4: Aktivita zákazníkov podľa roku narodenia
```sql
SELECT
  c.birth_year,
  COUNT(*) AS sales_count
FROM FACT_STORE_SALES f
JOIN DIM_CUSTOMER c ON f.customer_sk = c.customer_sk
GROUP BY c.birth_year
ORDER BY c.birth_year;
```
Kód slúži na vytvorenie grafu, ktorý vizualizuje počet nákupov podľa roku narodenia zákazníkov. Pomáha analyzovať, ktoré vekové skupiny sú najaktívnejšie.

## Graf 5: Priemerný počet položiek na transakciu podľa obchodu a kategórie
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
Kód slúži na vytvorenie grafu, ktorý vizualizuje priemerný počet kusov na transakciu podľa obchodu a kategórie. Je vhodný na porovnanie nákupného správania medzi predajňami.

## Graf 6: Top kategórie v jednotlivých mestách podľa počtu transakcií
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
Kód slúži na vytvorenie grafu, ktorý vizualizuje najčastejšie kombinácie mesto–kategória podľa počtu transakcií. Pomáha identifikovať regionálne preferencie produktov.

**Autori:Lukáš Horvát,Marco Gunda**
