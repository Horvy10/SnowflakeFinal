# ELT proces – TPC-DS dataset (Snowflake)

Tento projekt prezentuje kompletnú implementáciu **ELT procesu a dátového skladu (DWH)** v prostredí **Snowflake** nad datasetom **TPC-DS**, ktorý je dostupný prostredníctvom **Snowflake Marketplace**.  
Cieľom projektu je návrh a implementácia **dimenzionálneho modelu (Star Schema)** a tvorba analytických vizualizácií nad agregovanými dátami.

Projekt je vypracovaný ako záverečné zadanie k predmetu zameranému na dátové sklady a analytické systémy.

---

## 1. Úvod a popis zdrojových dát

### 1.1 Výber datasetu

Pre tento projekt bol zvolený dataset **TPC-DS**, ktorý predstavuje štandardizovaný benchmark pre analytické databázy. Dataset simuluje **retailový biznis proces** (predaj v kamenných obchodoch, zákazníci, produkty, dátumové dimenzie).

Dôvody výberu datasetu:
- dataset je **dostupný zdarma** v Snowflake Marketplace,
- obsahuje **reálne použiteľnú biznis doménu** (retail),
- je vhodný na návrh **hviezdicovej schémy**,
- umožňuje tvorbu analytických dotazov a dashboardov.

### 1.2 Biznis proces

Analyzovaný biznis proces:
- predaj produktov v kamenných obchodoch,
- správanie zákazníkov,
- tržby, množstvo predaného tovaru,
- časové trendy predaja.

Analýza je zameraná najmä na:
- vývoj predaja v čase,
- správanie zákazníkov,
- porovnanie predajov medzi obchodmi a produktmi.

---

## 2. ERD – pôvodná dátová štruktúra

Pôvodná dátová štruktúra vychádza zo staging tabuliek vytvorených zo zdrojového datasetu TPC-DS.

Použité staging tabuľky:
- `customer_staging`
- `date_staging`
- `item_staging`
- `store_staging`
- `store_sales_staging`

Tieto tabuľky predstavujú relačný model s väzbami medzi entitami (zákazník, produkt, obchod, dátum a predaj).

> ERD diagram pôvodnej štruktúry je uložený v priečinku `/img/erd.png`.

---

## 3. Návrh dimenzionálneho modelu (Star Schema)

Na základe ERD bol navrhnutý **hviezdicový model (Star Schema)** podľa Kimballovej metodológie.

### 3.1 Faktová tabuľka

**fact_store_sales**

Obsahuje metriky predaja a cudzie kľúče na dimenzie.

Hlavné stĺpce:
- `ss_id` – primárny kľúč faktovej tabuľky
- `ss_quantity` – množstvo predaných kusov
- `ss_net_paid` – čistá hodnota predaja
- `ss_sales_price` – cena predaja
- `item_sk` – FK na dimenziu produktu
- `store_sk` – FK na dimenziu obchodu
- `customer_sk` – FK na dimenziu zákazníka
- `date_sk` – FK na dimenziu dátumu

### 3.2 Dimenzie

#### dim_item (SCD Typ 0)
- `item_sk` (PK)
- `item_id`
- `item_desc`
- `category`
- `class`
- `brand`

#### dim_store (SCD Typ 0)
- `store_sk` (PK)
- `store_id`
- `store_name`
- `city`
- `state`
- `country`

#### dim_customer (SCD Typ 1)
- `customer_sk` (PK)
- `first_name`
- `last_name`
- `gender`
- `birth_year`
- `current_country`

#### dim_date (SCD Typ 0)
- `date_sk` (PK)
- `date`
- `year`
- `month`
- `quarter`
- `day_name`

> Star schema diagram je uložený v priečinku `/img/star_schema.png`.

---

## 4. ELT proces v Snowflake

### 4.1 Extract

Zdrojové dáta pochádzajú zo Snowflake Marketplace:
- databáza: `TPCDS`
- schéma: `PUBLIC`

Staging tabuľky boli vytvorené pomocou:

```sql
CREATE OR REPLACE TABLE customer_staging AS
SELECT * FROM TPCDS.PUBLIC.CUSTOMER;
