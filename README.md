# **ELT proces datasetu TPC-DS (Retail Sales)**

Tento repozitár predstavuje finálnu implementáciu **ELT procesu v Snowflake** nad datasetom **TPC-DS 10TB Managed Iceberg**, dostupným v **Snowflake Marketplace**. Projekt sa zameriava na analýzu maloobchodného predaja (store sales) a správania zákazníkov naprieč obchodmi, produktmi, časom a geografickými lokalitami.

Cieľom projektu je demonštrovať návrh a implementáciu **dátového skladu so schémou hviezdy (Star Schema)**, využitie **window functions**, ako aj tvorbu **vizualizácií nad agregovanými dátami**.

---

## **1. Úvod a popis zdrojových dát**

Pre tento projekt bol zvolený dataset **TPC-DS**, ktorý simuluje reálne transakčné dáta maloobchodného reťazca. Dataset podporuje analytické dotazy typické pre retail doménu, ako sú analýzy predaja, správania zákazníkov a výkonnosti obchodov.

### Prečo TPC-DS:
- dostupný zdarma v Snowflake Marketplace,
- realistický retailový biznis proces,
- bohatá dátová štruktúra vhodná pre DWH,
- často používaný benchmark v praxi.

### Použité zdrojové tabuľky:
- **DATE_DIM** – kalendárna dimenzia
- **ITEM** – produkty
- **STORE** – obchody a geografia
- **CUSTOMER** – zákazníci
- **STORE_SALES** – transakčné dáta (predaje)

---

## **1.1 Dátová architektúra – ERD**

Pôvodné dáta sú uložené v normalizovanom relačnom modeli (ERD), typickom pre OLTP/benchmark databázy. ERD diagram znázorňuje vzťahy medzi tabuľkami STORE_SALES, ITEM, STORE, CUSTOMER a DATE_DIM.

<img width="500" height="500" alt="erd" src="https://github.com/user-attachments/assets/b7ccd69b-3662-468c-ac50-cd051b7d7f87" />


---

## **2. Dimenzionálny model (Star Schema)**

Na analytické účely bol navrhnutý **hviezdicový model** podľa Kimballovej metodológie.

### Faktová tabuľka:
- **FACT_STORE_SALES**
  - metriky: `ss_quantity`, `ss_sales_price`, `ss_net_paid`
  - cudzie kľúče na všetky dimenzie

### Dimenzie:
- **DIM_DATE** (SCD Typ 0)
- **DIM_ITEM** (SCD Typ 0)
- **DIM_STORE** (SCD Typ 0)
- **DIM_CUSTOMER** (SCD Typ 1)

Hviezdicová schéma zjednodušuje analytické dotazy a umožňuje efektívne agregácie.

<img width="500" height="500" alt="hviezda" src="https://github.com/user-attachments/assets/93f5f899-3150-4d89-bb78-0d60ca8d6021" />


---

## **3. ELT proces v Snowflake**

### **3.1 Extract**
Dáta boli extrahované zo Snowflake Marketplace databázy:

```
TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG
```

Pre každý zdroj bol vytvorený staging objekt pomocou `CREATE OR REPLACE TABLE AS SELECT`.

---

### **3.2 Load**
Dáta boli načítané do vlastnej databázy **BOA_DB** a schémy **PROJEKT_STAGING**. V tejto vrstve prebehla základná filtrácia (napr. predaje od roku 2000).

---

### **3.3 Transform**
V tejto fáze boli:
- vytvorené dimenzie a faktová tabuľka,
- aplikované CAST-y a deduplikácia,
- implementované **window functions** vo faktovej tabuľke.

#### Použité window functions:
- **SUM() OVER()** – kumulatívne tržby obchodu,
- **RANK() OVER()** – poradie predajov v rámci obchodu,
- **LAG() OVER()** – predchádzajúca hodnota nákupu zákazníka.

Tieto funkcie umožňujú pokročilú analytiku bez nutnosti ďalších agregácií.

---

## **4. Vizualizácia dát**

Dashboard obsahuje **6 vizualizácii**, vytvorených priamo zo SQL dotazov nad faktovou tabuľkou.

### Príklady vizualizácií:
1. Počet transakcií podľa dní v týždni a obchodov
2. Najaktívnejšie mestá podľa počtu transakcií
3. Najlepšie štáty podľa objemu predaja
4. Veľkosť nákupného košíka podľa obchodu a kategórie
5. Počet transakcií podľa kategórie a mesta
6. Aktivita predajní v konkrétny deň (napr. štvrtok)

Vizualizácie kombinujú viacero dimenzií a poskytujú komplexný pohľad na dáta.

<img width="500" height="500" alt="viz2" src="https://github.com/user-attachments/assets/4c4d2706-8db6-44a9-a71d-e416432ee95e" />
<img width="500" height="500" alt="viz1" src="https://github.com/user-attachments/assets/4515685d-86a0-4e40-b432-21e2490b15b0" />


---



---

Autori:Lukáš Horvát, Marco Gunda
