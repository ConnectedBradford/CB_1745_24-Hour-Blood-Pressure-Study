WITH 

CRP_primary_care as (

SELECT 
  a.person_id, 
  b.ctv3code, 
  b.ctv3text,
  b.snomedcode,
  CAST(b.numericvalue AS BIGNUMERIC) AS CRP_value,
  b.dateevent,
  a.Date_GCAPMR_Diagnosis
FROM `yhcr-prd-phm-bia-core.CB_1745.PMR_GCA_Cohort` a
INNER JOIN `yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.tbl_srcode` b
ON a.person_id = b.person_id
--WHERE snomedcode in ('999651000000107', '1001371000000100') #CRP
--WHERE snomedcode = '1022511000000103' #ESR
--WHERE snomedcode in ('1022501000000100', '1022501000000100', '993911000000103', '365651002') #plasma viscosity
--WHERE snomedcode in ('1022431000000105', '1107511000000100', '1107531000000108', '271026005', '1022451000000103') #Hb
--WHERE snomedcode in('1022651000000100') #platelet

AND b.dateevent <= a.Date_GCAPMR_Diagnosis),

# filter  

CRP_primary_care_filtered as (
select
*,
row_number() over (partition by CRP_primary_care.CRP_value, dateevent, person_id) as dup_count
 from CRP_primary_care
 where CRP_value is not null), #need to think about this

# remove duplicates
CRP_readings_filtered_no_duplicates as (
select
* 
from CRP_primary_care_filtered
where dup_count=1),


CRP1 as (
    SELECT
  *, 
  CRP_value as CRP_result,
  FROM CRP_readings_filtered_no_duplicates),

reading_join as (
  SELECT 
  CRP1.person_id,
  CRP1.CRP_result,
  CRP1.dateevent as datetimeevent_CRP,

  CRP1.Date_GCAPMR_Diagnosis,
  extract(date from CRP1.dateevent) as date_CRP,
  FROM CRP1
  WHERE datetime_diff(CRP1.Date_GCAPMR_Diagnosis,CRP1.dateevent,day) < 366),


filter_daily as (

#Here I have selected the first blood pressure recording following admission. 
  SELECT
  *,
  rank() OVER (PARTITION BY person_id ORDER BY datetimeevent_CRP desc) as CRP_seq, 
  row_number() over (partition by person_id, date_CRP order by CRP_result desc) as systolic_daily 
  from 
  reading_join rj)


select
person_id,
filter_daily.CRP_result as ESR,
Date_GCAPMR_Diagnosis,
date_CRP


from filter_daily
where CRP_seq = 1
and systolic_daily = 1 

order by person_id


