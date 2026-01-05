# **ELT proces datasetu TPC-DS (Retail Sales Analytics)**

Tento repozitár dokumentuje kompletný proces spracovania dát pomocou **ELT architektúry v prostredí Snowflake**. Projekt je zameraný na návrh a implementáciu **dátového skladu (DWH)** s využitím **dimenzionálneho modelu typu Star Schema** nad datasetom **TPC-DS**, dostupným v **Snowflake Marketplace**.

Výsledný dátový model umožňuje multidimenzionálnu analýzu predajných dát, správania zákazníkov a časových trendov v maloobchodnom prostredí.

---

## **1. Úvod a popis zdrojových dát / Odôvodnenie výberu**

### **1.1 Charakteristika datasetu**

Dataset **TPC-DS** predstavuje štandardizovaný benchmark pre analytické databázy a simuluje reálne obchodné procesy veľkého maloobchodného reťazca. Obsahuje údaje o zákazníkoch, produktoch, predajniach, predajných transakciách a časových dimenziách.

---

### **1.2 Voľba datasetu**

Dataset bol zvolený z dôvodu dostupnosti v Snowflake Marketplace, realistickej štruktúry dát a vhodnosti pre návrh dimenzionálneho modelu.

---

### **1.3 Podporovaný biznis proces**

Dáta podporujú analýzu predaja, správania zákazníkov a výkonnosti predajní v čase.

---

## **2. Návrh dimenzionálneho modelu**

Navrhnutý bol **hviezdicový model (Star Schema)** pozostávajúci z jednej faktovej tabuľky a viacerých dimenzií.

---

## **3. ELT proces v Snowflake**

### **Extract**
Dáta boli extrahované zo Snowflake Marketplace do staging tabuliek.

### **Load**
Staging tabuľky boli použité na naplnenie dimenzií a faktovej tabuľky.

### **Transform**
Transformácie zahŕňali čistenie dát, deduplikáciu a použitie window functions.

---

## **4. Vizualizácia dát**

Vytvorených bolo minimálne 5 vizualizácií v Snowflake Dashboarde.

---

**Autor:**  
Lukáš Horavát,Marco Gunda
