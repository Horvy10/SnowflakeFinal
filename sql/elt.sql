CREATE OR REPLACE SCHEMA BOA_DB.PROJEKT_STAGING;
USE SCHEMA PROJEKT_STAGING;

//Vytvorenie staging tabuliek  
----------------------------------------------------------------------
CREATE OR REPLACE TABLE PROJEKT_STAGING.DATE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.DATE_DIM
WHERE D_YEAR >= 2000;

//ITEM
CREATE OR REPLACE TABLE PROJEKT_STAGING.ITEM_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.ITEM;

//STORE
CREATE OR REPLACE TABLE PROJEKT_STAGING.STORE_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.STORE;

//CUSTOMER
CREATE OR REPLACE TABLE PROJEKT_STAGING.CUSTOMER_STAGING AS
SELECT *
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.CUSTOMER;

//STORE_SALES
CREATE OR REPLACE TABLE PROJEKT_STAGING.STORE_SALES_STAGING AS
SELECT ss.*
FROM TPCDS_10TB_MANAGED_ICEBERG.TPCDS_SF10T_ICEBERG.STORE_SALES ss
JOIN PROJEKT_STAGING.DATE_STAGING d
  ON ss.ss_sold_date_sk = d.d_date_sk
WHERE ss.ss_sold_date_sk IS NOT NULL
  AND ss.ss_item_sk IS NOT NULL
  AND ss.ss_store_sk IS NOT NULL
  AND ss.ss_customer_sk IS NOT NULL
LIMIT 100000;





CREATE OR REPLACE SCHEMA BOA_DB.PROJEKT_STAR;
USE SCHEMA PROJEKT_STAR;

//Vytvorenie Dimenzií a tabuľky Faktov 
----------------------------------------------------------------------

//DIM_DATE 
CREATE OR REPLACE TABLE DIM_DATE AS
SELECT
    d_date_sk                         AS date_sk,
    d_date                            AS date,
    d_year                            AS year,
    d_moy                             AS month,
    d_qoy                             AS quarter,
    d_day_name                        AS day_name
FROM BOA_DB.PROJEKT_STAGING.DATE_STAGING
WHERE d_date_sk IS NOT NULL;


//DIM_ITEM
CREATE OR REPLACE TABLE DIM_ITEM AS
SELECT
    i_item_sk                         AS item_sk,
    i_item_id                         AS item_id,
    i_item_desc                       AS item_desc,
    i_category                        AS category,
    i_class                           AS class,
    i_brand                           AS brand
FROM BOA_DB.PROJEKT_STAGING.ITEM_STAGING
WHERE i_item_sk IS NOT NULL;


//DIM_STORE 
CREATE OR REPLACE TABLE DIM_STORE AS
SELECT
    s_store_sk                        AS store_sk,
    s_store_id                        AS store_id,
    s_store_name                      AS store_name,
    s_city                            AS city,
    s_state                           AS state,
    s_country                         AS country
FROM BOA_DB.PROJEKT_STAGING.STORE_STAGING
WHERE s_store_sk IS NOT NULL;


//DIM_CUSTOMER 
CREATE OR REPLACE TABLE DIM_CUSTOMER AS
SELECT
    c_customer_sk                     AS customer_sk,
    c_first_name                      AS first_name,
    c_last_name                       AS last_name,    
    c_birth_year                      AS birth_year,
    c_birth_country                   AS birth_country,
    c_email_address                   AS email_adress
FROM BOA_DB.PROJEKT_STAGING.CUSTOMER_STAGING
WHERE c_customer_sk IS NOT NULL;




//FACT_STORE_SALES faktova tabulka
CREATE OR REPLACE TABLE FACT_STORE_SALES AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY ss.ss_sold_date_sk,
                 ss.ss_store_sk,
                 ss.ss_item_sk,
                 ss.ss_customer_sk
    ) AS ss_id,

//foreign keys na DIM
    d.date_sk        AS date_sk,
    i.item_sk        AS item_sk,
    s.store_sk       AS store_sk,
    c.customer_sk    AS customer_sk,

    //Meratelne hodnoty
    ss.ss_quantity        AS ss_quantity,
    ss.ss_net_paid        AS ss_net_paid,
    ss.ss_sales_price     AS ss_sales_price,


    //Vypocita kumulativny obrat pre kazdy obchod 
    SUM(ss.ss_net_paid) OVER (
        PARTITION BY ss.ss_store_sk
        ORDER BY ss.ss_sold_date_sk
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_store_revenue,

   
    //TOP predaje v jednotlivom obchode.
    RANK() OVER (
        PARTITION BY ss.ss_store_sk
        ORDER BY ss.ss_net_paid DESC
    ) AS sale_rank_in_store,

  
  // aktualny nakup - predchadzajuci nákup zakaznika    
    LAG(ss.ss_net_paid) OVER (
        PARTITION BY ss.ss_customer_sk
        ORDER BY ss.ss_sold_date_sk
    ) AS prev_customer_payment,


FROM BOA_DB.PROJEKT_STAGING.STORE_SALES_STAGING ss

JOIN DIM_DATE d
    ON ss.ss_sold_date_sk = d.date_sk

JOIN DIM_ITEM i
    ON ss.ss_item_sk = i.item_sk

JOIN DIM_STORE s
    ON ss.ss_store_sk = s.store_sk

JOIN DIM_CUSTOMER c
    ON ss.ss_customer_sk = c.customer_sk

WHERE
    ss.ss_sold_date_sk IS NOT NULL
    AND ss.ss_item_sk IS NOT NULL
    AND ss.ss_store_sk IS NOT NULL
    AND ss.ss_customer_sk IS NOT NULL;










