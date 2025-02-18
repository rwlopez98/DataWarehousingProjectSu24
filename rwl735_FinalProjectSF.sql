--RWL735 Final Project Data Warehouse
--Author: Ray Lopez
--UTID: rwl735
--Last Edited: 8/17/24

USE ROLE SYSADMIN;
USE ROLE ACCOUNTADMIN;

--Dropping all tables for demo
USE SCHEMA ELT_STAGE;
drop table data_dw;
drop table item_dw;
drop table user_dw;

use schema edw_silver_layer;
drop table movies_with_all_ratings;

use schema edw_gold_layer;
drop table average_rating;
drop table "Average_Rating_By_Genre";

--Declaring Azure Tenant_ID var
SET tenant_id_dev = '42dce49a-fcad-48ef-864f-218e6545acdb';

--Creating integration with Azure DEV Env
CREATE OR REPLACE STORAGE INTEGRATION rwl735_final_project_storage_integration
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = AZURE
    ENABLED = TRUE
    AZURE_TENANT_ID = $tenant_id_dev 
    STORAGE_ALLOWED_LOCATIONS = ('azure://rwlopezblobinfomgmt.blob.core.windows.net/final-project/');

--Granting full rights to SYSADMIN
GRANT OWNERSHIP ON INTEGRATION rwl735_final_project_storage_integration TO SYSADMIN;

--Gettting consent URL and multi-tenant app name
DESC STORAGE INTEGRATION rwl735_final_project_storage_integration;

--Creating database to hold all my objects and data.
CREATE OR REPLACE DATABASE rwl735_final_dw
COMMENT = 'This database is my DW for my final project';

--Creating schema
CREATE OR REPLACE SCHEMA ELT_STAGE
COMMENT = 'This schema is used to load data from ADLS gen2(Azure Datalake) to Snowflake';

CREATE OR REPLACE SCHEMA EDW_SILVER_LAYER
COMMENT = 'This schema is used to create Silver Layer';

--Granting access to SYSADMIN
GRANT ALL ON DATABASE rwl735_final_dw TO SYSADMIN;
SHOW GRANTS ON DATABASE rwl735_final_dw;

--Creating a warehouse for compute processing and grant privileges
CREATE OR REPLACE WAREHOUSE rwl735_final_wh
WITH    WAREHOUSE_SIZE = 'XSMALL'
        WAREHOUSE_TYPE = 'STANDARD'
        AUTO_SUSPEND = 600
        AUTO_RESUME = TRUE
        MIN_CLUSTER_COUNT = 1
        MAX_CLUSTER_COUNT = 2
        SCALING_POLICY = 'STANDARD'
        COMMENT = 'DW Computing Warehouse';

GRANT ALL, MODIFY ON WAREHOUSE rwl735_final_wh TO ROLE SYSADMIN;
SHOW GRANTS ON WAREHOUSE rwl735_final_wh;

--Using grant to assign role speciffic privileges
USE ROLE SECURITYADMIN;

GRANT OWNERSHIP ON SCHEMA rwl735_final_dw.ELT_STAGE TO SYSADMIN;
GRANT OWNERSHIP ON SCHEMA rwl735_final_dw.EDW_SILVER_LAYER TO SYSADMIN;

--Creating an external stage in snowflake to connect to my raw container
USE ROLE accountadmin;
USE DATABASE rwl735_final_dw;
USE WAREHOUSE rwl735_final_wh;
USE SCHEMA ELT_STAGE;

create or replace stage ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE
comment = 'Raw External Stage for the ELT Account on the RRC DataLake Blob Container'
storage_integration = rwl735_final_project_storage_integration
url = 'azure://rwlopezblobinfomgmt.blob.core.windows.net/final-project/';

LIST @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/;
LIST @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_data.csv;
LIST @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_item.csv;
LIST @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_user.csv;

SELECT $1, $2, $3
FROM @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_data.csv;

SELECT $1, $2, $3
FROM @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_item.csv;

SELECT $1, $2, $3
FROM @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_user.csv;

--Creating a table to store movie information data file
create OR replace transient table ELT_STAGE.item_dw (
itemid int primary key,
movietitle string,
releasedate date,
videoreleasedate date,
imdb_url string,
unknown int, 
action int,
adventure int,
animation int,
childrens int,
comedy int,
crime int,
documentary int,
drama int,
fantasy int,
filmNoir int,
Horror int,
Musical int,
Mystery int,
Romance int,
sciFi int,
Thriller int,
War int,
Western int
);

--Creating table to store user information
create OR replace transient table ELT_STAGE.user_dw (
userid int primary key,
age int,
gender varchar(1),
occupation string,
zipcode int
);

--Create a table to store data (review) data file
create OR replace transient table ELT_STAGE.data_dw (
userid int,
itemid int,
rating int,
timestamp int,
foreign key (userid) references user_dw(userid),
foreign key (itemid) references item_dw(itemid)
);

-- Creating a FILE FORMAT --> Example (CSV with headers)
CREATE OR REPLACE FILE FORMAT ELT_STAGE.ELT_CSV_COMMA_DELIMITED_HEADER
COMMENT = 'File Format for CSV comma delimited Column Header files'
COMPRESSION = 'NONE'
TYPE = CSV -- Set file tyle
FIELD_DELIMITER = ',' -- Delimits columns by comma
RECORD_DELIMITER = '\n' -- Delimits rows by line break
SKIP_HEADER = 1 -- Skip the first row and don’t treat as data
FIELD_OPTIONALLY_ENCLOSED_BY = '\042'
TRIM_SPACE = FALSE
ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
ESCAPE = '\134'
ESCAPE_UNENCLOSED_FIELD = 'NONE'
DATE_FORMAT = 'AUTO'
TIMESTAMP_FORMAT = 'AUTO'
EMPTY_FIELD_AS_NULL = TRUE;

TRUNCATE TABLE ELT_STAGE.item_dw;
---copy from product raw file into item_dw table
COPY INTO ELT_STAGE.item_dw
FROM @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_item.csv
FILE_FORMAT = ELT_STAGE.ELT_CSV_COMMA_DELIMITED_HEADER
ON_ERROR=CONTINUE;

SELECT *
FROM ELT_STAGE.item_dw;

TRUNCATE TABLE ELT_STAGE.user_dw;
---copy from sales raw file into user_dw table
COPY INTO ELT_STAGE.user_dw
FROM @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_user.csv
FILE_FORMAT = ELT_STAGE.ELT_CSV_COMMA_DELIMITED_HEADER
ON_ERROR=CONTINUE;

SELECT *
FROM ELT_STAGE.user_dw;

TRUNCATE TABLE ELT_STAGE.data_dw;
---copy from sales raw file into data_dw table
COPY INTO ELT_STAGE.data_dw
FROM @ELT_STAGE.ELT_FINAL_PROJECT_EXTERNAL_STAGE/final_data.csv
FILE_FORMAT = ELT_STAGE.ELT_CSV_COMMA_DELIMITED_HEADER
ON_ERROR=CONTINUE;

SELECT *
FROM ELT_STAGE.data_dw;

--------------------------------------------------------------------
--Creating Views that merge our raw data into a refined dataset
CREATE OR REPLACE TABLE edw_silver_layer.Movies_With_All_Ratings as (
Select
    distinct i.itemid,
    substring(i.movietitle, 1, length(i.movietitle)-7) as movietitleShort,
    substring(i.movietitle, length(i.movietitle)-4, 4) as releaseyear,
    d.rating as rating
from ELT_STAGE.item_dw i
right join ELT_STAGE.data_dw d on i.itemid = d.itemid
);
--Use the silver layer schema
use SCHEMA edw_silver_layer;
--Select records from the merged silver layer table of sales_by_products
select *
from Movies_With_All_Ratings
order by itemid;

--------------------------------------------------------------------
--Creating Views that aggregage our silver layer table to provide useful insight
RWL735_FINAL_DW.EDW_GOLD_LAYER."Average_Rating_By_Genre"

select *
from edw_gold_layer."Average_Rating_By_Genre";