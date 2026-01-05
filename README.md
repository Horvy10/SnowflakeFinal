##ELT proces datasetu TPC-DS (Retail Sales Analytics)

Tento repozitár prezentuje kompletnú implementáciu ELT procesu v Snowflake a návrh dátového skladu založeného na dimenzionálnom modeli typu Star Schema. Projekt pracuje s datasetom TPC-DS, ktorý je dostupný prostredníctvom Snowflake Marketplace.

Cieľom projektu je analyzovať maloobchodný predaj, správanie zákazníkov, výkonnosť produktov a predajní v čase. Výsledný dátový model umožňuje multidimenzionálnu analýzu a tvorbu analytických vizualizácií nad agregovanými dátami.

1. Úvod a popis zdrojových dát

V tomto projekte analyzujeme dáta z oblasti retailového predaja, ktoré simulujú reálne obchodné procesy veľkého maloobchodného reťazca. Analýza je zameraná najmä na:

správanie zákazníkov,

predaj produktov v jednotlivých predajniach,

časové trendy tržieb,

identifikáciu najvýkonnejších produktov a zákazníkov.

Zdroj dát

Zdrojové dáta pochádzajú z datasetu TPC-DS (Decision Support Benchmark), ktorý je dostupný v Snowflake Marketplace ako súčasť databázy SNOWFLAKE_SAMPLE_DATA.

Dataset bol spracovaný ako reprezentatívna vzorka (100 riadkov) z dôvodu kvótových a výpočtových limitov Snowflake účtu. Cieľom projektu nie je práca s veľkým objemom dát, ale demonštrácia správneho návrhu ELT procesu a dátového skladu.

1.1 Zdrojové tabuľky

V projekte boli využité nasledujúce tabuľky zo zdrojového datasetu:

CUSTOMER – demografické údaje o zákazníkoch

ITEM – informácie o produktoch (kategória, značka)

STORE – údaje o predajniach a ich lokalite

DATE_DIM – kalendárna dimenzia

STORE_SALES – transakčné údaje o predajoch

ERD diagram pôvodnej dátovej štruktúry je uložený v priečinku
(pridaj obrázok!!!)

2. Dimenzionálny model

Pre analytické účely bol navrhnutý hviezdicový model (Star Schema) podľa Kimballovej metodológie. Model pozostáva z jednej faktovej tabuľky fact_store_sales a štyroch dimenzií.

Použité dimenzie

dim_customer – zákazníci

dim_item – produkty

dim_store – predajne

dim_date – časová dimenzia

Faktová tabuľka

fact_store_sales – predajné transakcie

📌 Schéma hviezdy je znázornená na diagrame uloženom v
/img/star_schema.png

2.1 Dimenzie
dim_customer (SCD Typ 1)

PK: customer_sk

Atribúty: meno, priezvisko, pohlavie, rok narodenia, krajina

Zmeny sa prepíšu (SCD Type 1)

dim_item (SCD Typ 1)

PK: item_sk

Atribúty: názov produktu, kategória, značka

dim_store (SCD Typ 1)

PK: store_sk

Atribúty: názov predajne, mesto, štát, krajina

dim_date (SCD Typ 0)

PK: date_sk

Atribúty: dátum, rok, mesiac, deň, kvartál

Nemenná dimenzia (SCD Type 0)

2.2 Faktová tabuľka
fact_store_sales

PK: sales_sk

FK: customer_sk, item_sk, store_sk, date_sk

Metriky: quantity, sales_amount

Použité window functions:

SUM(sales_amount) OVER (PARTITION BY customer_sk)

RANK() OVER (PARTITION BY store_sk ORDER BY sales_amount DESC)

3. ELT proces v Snowflake

ELT proces bol implementovaný v troch hlavných krokoch: Extract, Load, Transform.

3.1 Extract

Dáta boli extrahované zo Snowflake Marketplace databázy SNOWFLAKE_SAMPLE_DATA do staging vrstvy pomocou príkazu:

CREATE OR REPLACE TABLE customer_staging AS
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER;

3.2 Load

Zo staging tabuliek boli naplnené dimenzie a faktová tabuľka pomocou príkazov CREATE OR REPLACE TABLE AS SELECT.

3.3 Transform

Transformácie zahŕňali:

výber relevantných atribútov,

deduplikáciu dát,

čistenie údajov,

výpočet agregácií,

použitie window functions vo faktovej tabuľke.

Výsledkom je optimalizovaný dimenzionálny model vhodný na analytické dotazy.

4. Vizualizácia dát

V Snowflake Dashboarde bolo vytvorených 5 analytických vizualizácií:

Celkové tržby v čase

Top produkty podľa tržieb

Výkonnosť predajní podľa štátov

Top zákazníci podľa obratu

Poradie produktov v rámci predajní

Každá vizualizácia obsahuje SQL dotaz, obrázok grafu a stručnú interpretáciu výsledkov.

5. Štruktúra repozitára
/sql
  ├── extract.sql
  ├── load.sql
  ├── transform_dimensions.sql
  ├── transform_fact.sql

/img
  ├── source_erd.png
  ├── star_schema.png
  ├── viz_1.png
  ├── viz_2.png
  ├── viz_3.png
  ├── viz_4.png
  ├── viz_5.png

README.md

Záver

Projekt demonštruje kompletný ELT proces v Snowflake, návrh dimenzionálneho modelu typu Star Schema, použitie window functions a tvorbu analytických vizualizácií. Riešenie je navrhnuté tak, aby bolo možné ho rozšíriť na väčší objem dát bez zmeny architektúry.

Autor:
Lukáš Horvát,Marco Gunda
