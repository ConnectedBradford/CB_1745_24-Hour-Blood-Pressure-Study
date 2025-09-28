WITH 

bp_primary_care as (

SELECT 
  a.person_id, 
  b.ctv3code, 
  b.ctv3text,
  b.snomedcode,
  CAST(b.numericvalue AS BIGNUMERIC) AS bp_value,
  b.dateevent,
  a.GCAPMR_date_of_diagnosis
FROM `yhcr-prd-phm-bia-core.CB_1745.Final_cohort_with_steroids` a
INNER JOIN `yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.tbl_srcode` b
ON a.person_id = b.person_id
WHERE CAST(b.snomedcode AS STRING) IN (
  SELECT CAST(code AS STRING) 
  FROM `yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.BP_recording_codes`
) 
AND b.dateevent < a.GCAPMR_date_of_diagnosis),

# filter  

bp_primary_care_filtered as (
select
*,
row_number() over (partition by bp_primary_care.bp_value, dateevent, person_id) as dup_count
 from bp_primary_care
 where bp_value > 10),

# remove duplicates
bp_readings_filtered_no_duplicates as (
select
* 
from bp_primary_care_filtered
where dup_count=1),

diastolic as (
    SELECT
  *, 
  bp_value as diastolic_value,
  FROM bp_primary_care
  WHERE ctv3text like "%iastolic%"),

  systolic as (
    SELECT 
    *,
    bp_value as systolic_value
    FROM bp_primary_care
    WHERE ctv3text like "%ystolic%"),

reading_join as (
  SELECT 
  diastolic.person_id,
  systolic_value,
  diastolic_value,
  diastolic.dateevent as datetimeevent_diastolic,
  systolic.dateevent as datetimeevent_systolic,
   diastolic.GCAPMR_date_of_diagnosis,
  extract(date from systolic.dateevent) as date_systolic,
  FROM diastolic
  FULL JOIN systolic 
  ON 
  diastolic.person_id = systolic.person_id AND diastolic.dateevent = systolic.dateevent

  #here i have filtered out reading which, were they a true measurement of a person's blood pressure, would result in urgnet hospital admission or indicate someone who is dying. these values which chosen empirically based on my own clinical knowledge. 

  WHERE datetime_diff(diastolic.dateevent,diastolic.GCAPMR_date_of_diagnosis,day) < 45 AND systolic_value >79 AND systolic_value <230 AND diastolic_value >49),

  filter_daily as (

#Here I have selected the first blood pressure recording following admission. 
  SELECT
  *,
  rank() OVER (PARTITION BY person_id ORDER BY datetimeevent_systolic) as bp_seq, 
  row_number() over (partition by person_id, date_systolic order by systolic_value) as systolic_daily 
  from 
  reading_join rj),

blood_pressure_readings as(

select
* 
from filter_daily
--and systolic_daily = 1 
--and bp_seq = 1
),

daily_averages as (

select

blood_pressure_readings.person_id,
date_systolic as reading_date,
avg(blood_pressure_readings.systolic_value) as daily_mean_sys,
avg(blood_pressure_readings.diastolic_value) as daily_mean_dias

from
blood_pressure_readings

GROUP BY
    blood_pressure_readings.person_id, 
    date_systolic

),

Total_averages as (
SELECT
    person_id,
    AVG(daily_mean_sys) AS mean_systolic,
    AVG(daily_mean_dias) AS mean_diastolic
FROM
    daily_averages
GROUP BY
    person_id)

select
avg(mean_systolic) sys,
avg(mean_diastolic) dias,
stddev(mean_systolic),
stddev(mean_diastolic)
from total_averages