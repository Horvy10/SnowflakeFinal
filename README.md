ELT proces datasetu TPC-DS (Retail Sales Analytics)

Tento repozitár dokumentuje kompletný proces spracovania dát pomocou ELT architektúry v prostredí Snowflake. Projekt je zameraný na návrh a implementáciu dátového skladu (DWH) s využitím dimenzionálneho modelu typu Star Schema nad datasetom TPC-DS, dostupným v Snowflake Marketplace.

Výsledný dátový model umožňuje multidimenzionálnu analýzu predajných dát, správania zákazníkov a časových trendov v maloobchodnom prostredí.

1. Úvod a popis zdrojových dát / Odôvodnenie výberu
1.1 Charakteristika datasetu

Dataset TPC-DS predstavuje štandardizovaný benchmark pre analytické databázy a simuluje reálne obchodné procesy veľkého maloobchodného reťazca. Obsahuje údaje o:

zákazníkoch,

produktoch,

predajniach,

predajných transakciách,

časových dimenziách.

Dáta sú vhodné na analytické dotazy typu Decision Support a sú často využívané v akademickom aj komerčnom prostredí.

1.2 Voľba datasetu

Dataset TPC-DS bol zvolený z nasledujúcich dôvodov:

dostupnosť priamo v Snowflake Marketplace (bez potreby externých zdrojov),

realistická simulácia retailového biznis procesu,

bohatá štruktúra dát vhodná pre návrh dimenzionálneho modelu,

vhodnosť na demonštráciu ELT procesu a analytických vizualizácií.

1.3 Podporovaný biznis proces

Analyzované dáta podporujú najmä tieto biznis procesy:

sledovanie predaja produktov,

analýzu správania zákazníkov,

hodnotenie výkonnosti predajní,

časové porovnania tržieb.

Výsledky analýzy môžu byť využité pri rozhodovaní o marketingových stratégiách, optimalizácii sortimentu a plánovaní predaja.

1.4 Zdrojové tabuľky

Zo zdrojového datasetu boli využité nasledujúce tabuľky:

CUSTOMER – demografické údaje zákazníkov

ITEM – informácie o produktoch

STORE – údaje o predajniach

DATE_DIM – kalendárna dimenzia

STORE_SALES – transakčné údaje o predaji

📌 ERD diagram pôvodnej dátovej štruktúry je uložený v priečinku /img/source_erd.png.

2. Návrh dimenzionálneho modelu

Pre analytické spracovanie dát bol navrhnutý hviezdicový model (Star Schema) podľa Kimballovej metodológie.

Model pozostáva z jednej faktovej tabuľky a štyroch dimenzií:

fact_store_sales

dim_customer

dim_item

dim_store

dim_date

📌 Schéma hviezdy je znázornená na obrázku /img/star_schema.png.

2.1 Dimenzie
dim_customer (SCD Typ 1)

Obsahuje základné demografické údaje o zákazníkoch. Pri zmene údajov dochádza k prepísaniu existujúcich hodnôt.

dim_item (SCD Typ 1)

Obsahuje informácie o produktoch, ich kategórii a značke.

dim_store (SCD Typ 1)

Obsahuje údaje o predajniach a ich geografickej lokalite.

dim_date (SCD Typ 0)

Nemenná časová dimenzia slúžiaca na analýzu dát v čase.

2.2 Faktová tabuľka
fact_store_sales

Faktová tabuľka obsahuje informácie o predajných transakciách a prepojenia na všetky dimenzie.

Metriky:

množstvo predaných kusov,

celková suma predaja.

Vo faktovej tabuľke sú použité window functions, napríklad:

SUM(...) OVER (PARTITION BY ...)

RANK() OVER (ORDER BY ...)

3. ELT proces v Snowflake
3.1 Extract

Dáta boli extrahované zo Snowflake Marketplace databázy SNOWFLAKE_SAMPLE_DATA do staging vrstvy pomocou SQL príkazov typu:

CREATE OR REPLACE TABLE customer_staging AS
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER;

3.2 Load

Zo staging tabuliek boli naplnené dimenzie a faktová tabuľka pomocou príkazov CREATE OR REPLACE TABLE AS SELECT.

3.3 Transform

Transformácie zahŕňali:

výber relevantných atribútov,

deduplikáciu dát,

čistenie údajov,

agregácie,

použitie window functions.

4. Vizualizácia dát

V Snowflake Dashboarde bolo vytvorených minimálne 5 vizualizácií, ktoré zobrazujú:

vývoj tržieb v čase,

najpredávanejšie produkty,

výkonnosť predajní,

top zákazníkov,

poradie produktov podľa tržieb.

Každá vizualizácia obsahuje SQL dotaz, obrázok grafu a interpretáciu výsledkov.

Záver

Projekt demonštruje kompletný ELT proces v Snowflake, návrh dimenzionálneho dátového skladu a využitie analytických nástrojov na spracovanie retailových dát. Výsledný model je škálovateľný a pripravený na rozšírenie o väčší objem dát.

Autor:
Meno Priezvisko
