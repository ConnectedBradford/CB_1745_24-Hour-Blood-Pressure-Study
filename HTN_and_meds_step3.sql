# Run this code to correct date format

CREATE OR REPLACE TABLE `yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.HTN_after_GCA_and_meds_confirmation` AS  #Will need to use up to date table from previous step

SELECT  

*, 

PARSE_DATE('%Y-%m-%d', HTN_diagnosis_date) as Date_of_HTNdiagnosis 

FROM yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.HTN_after_GCA_and_meds_confirmation