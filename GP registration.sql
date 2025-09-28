|------------------------------------------------------------------|
|-----------------------GP Codes-------------------------------|
|------------------------------------------------------------------|

--OVERALL COHORT GP _INCL REGISTRATION TERMINATING BEFORE 2007
drop table SAILW0826V.GP_CODES_ALL
CREATE TABLE SAILW0826V.GP_CODES_ALL as (

SELECT distinct ALF_PE , PRAC_CD_PE, START_DATE, END_DATE  from SAIL0826v.WLGP_CLEAN_GP_REG_BY_PRAC_INCLNONSAIL_MEDIAN_20180820
WHERE START_DATE < '2018-12-31'
AND ALF_PE IS NOT NULL
) with DATA
SELECT count(DISTINCT ALF_PE) FROM SAILW0826V.GP_CODES_ALL

-- OVERALL COHORT REGISTERED AFTER 2007
drop table SAILW0826V.GP_CODES_2007
CREATE TABLE SAILW0826V.GP_CODES_2007 as (

SELECT distinct ALF_PE , PRAC_CD_PE, START_DATE, END_DATE  from SAIL0826v.WLGP_CLEAN_GP_REG_BY_PRAC_INCLNONSAIL_MEDIAN_20180820
WHERE START_DATE < '2018-12-31'
AND END_DATE !< '2007-01-01'
AND ALF_PE IS NOT NULL
) with DATA
SELECT count(DISTINCT ALF_PE) FROM SAILW0826V.GP_CODES_2007

--WHERE START_DATE between  '2007-01-01' and '2008-01-01' - SAME RESULT
--------------link to SAIL FINAL COHORT
DROP TABLE sailw0826v.COHORT_FINAL_GP_2007
CREATE TABLE sailw0826v.COHORT_FINAL_GP_2007 AS (
select * FROM SAILW0826V.COHORT_FINAL
LEFT JOIN SAILW0826V.GP_CODES_2007
USING (ALF_PE)
) WITH DATA
select * FROM sailw0826v.COHORT_FINAL_GP
SELECT count FROM sailw0826v.COHORT_FINAL_GP_2007
SELECT DISTINCT PRAC_CD_PE FROM sailw0826v.COHORT_FINAL_GP


--WHo was still registered by 2007

--FOR 2007 COHORT

drop table SAILW0826V.GP_CODES
CREATE TABLE SAILW0826V.GP_CODES as (

SELECT distinct ALF_PE , PRAC_CD_PE, START_DATE, END_DATE  from SAIL0826v.WLGP_CLEAN_GP_REG_BY_PRAC_INCLNONSAIL_MEDIAN_20180820
WHERE START_DATE < '2018-12-31'
AND END_DATE !< '2007-01-01'  -- aged >= 65 , <= 95 at 2009, UPPER LIMIT SAME AS eFI development
AND ALF_PE IS NOT NULL
) with data


--Check the table was created and count the rows and distinct rows to check one row per person. 

select * from SAILW0826V.GP_CODES
ORDER BY ALF_PE;
select count(*) FROM SAIL0826v.WLGP_CLEAN_GP_REG_BY_PRAC_INCLNONSAIL_MEDIAN_20180820
select count(*) from SAILW0826V.GP_CODES;
SELECT count(DISTINCT ALF_PE) FROM SAIL0826v.WLGP_CLEAN_GP_REG_BY_PRAC_INCLNONSAIL_MEDIAN_20180820
select count(DISTINCT ALF_PE) from SAILW0826V.GP_CODES;


--------------link to SAIL FINAL COHORT
DROP TABLE sailw0826v.COHORT_FINAL_GP
CREATE TABLE sailw0826v.COHORT_FINAL_GP AS (
select * FROM SAILW0826V.COHORT_FINAL
LEFT JOIN SAILW0826V.GP_CODES
USING (ALF_PE)
) WITH DATA
select * FROM sailw0826v.COHORT_FINAL_GP
SELECT count(DISTINCT ALF_PE) FROM sailw0826v.COHORT_FINAL_GP
SELECT count(DISTINCT PRAC_CD_PE) FROM sailw0826v.COHORT_FINAL_GP

--------------link to BP cohort
DROP TABLE sailw0826v.BP_2007_GP
CREATE TABLE sailw0826v.BP_2007_GP AS (
SELECT * FROM 
(SELECT  ALF_PE, WOB_WDS, GNDR_WDS, DOD, EVENT_CD, event_dt , treatment_start_dt, CANCER_WATCH_dt, CV_RISK_START_dt, EVENT_VAL
FROM SAILW0826V.bp_2007
WHERE BP_SEQ = 1)  
LEFT JOIN SAILW0826V.GP_CODES
USING (ALF_PE)
) WITH DATA

select count FROM sailw0826v.BP_2007_GP
ORDER BY ALF_PE
SELECT * FROM SAILW0826V.GP_CODES
ORDER BY ALF_PE
SELECT count (DISTINCT ALF_PE) FROM sailw0826v.BP_2007_GP
--SELECT count(DISTINCT PRAC_CD_PE) FROM sailw0826v.BP_2007_GP
--SELECT DISTINCT A.* , event_cd,  event_dt , EVENT_VAL , BP_SEQ FROM SAILW0826V.COHORT_FINAL AS A

--JOIN 
--(SELECT DISTINCT alf_pe, event_cd,  event_dt , EVENT_VAL , ROW_NUMBER() OVER (PARTITION BY ALF_PE ORDER BY EVENT_DT) AS BP_SEQ FROM SAIL0826V.WLGP_GP_EVENT_ALF_CLEANSED_20180820 
--WHERE (event_cd LIKE '246%' OR event_cd IN('2460.','90D.','8CE3.','R1y3.','662L.','R1y2.','ZV70B') )
--AND EVENT_VAL IS NOT NULL 
--AND event_val > 0 
--AND EVENT_DT BETWEEN '2007-01-01'AND '2008-01-01'
--) AS B
--USING (ALF_PE)

--WHERE ( months_between(DOD,event_dt) >= 6 OR  DOD IS NULL )
--ORDER BY ALF_PE , bp_seq )



----------------------------------------------------------

SELECT * FROM sailw0826v.alf_index_date
------------------------------------------------------------------------------------------
-------------Length of GP registrations for 1 years prior to index event by ALF_E -------------
------------------------------------------------------------------------------------------
DROP TABLE sailw0826v.gp_reg_1yr
CREATE TABLE sailw0826v.gp_reg_1yr AS (
SELECT
	ALF_PE,
	SUM(DIFF_DAYS) AS SUM_DAYS
FROM
	(
	---------------------------------------------------- start 3.
	SELECT
		alf_Pe ,
		DAYS_BETWEEN(NEW_END,
		NEW_START) AS DIFF_DAYS
	FROM
		(
		---------------------------------------------------- start 2.
		SELECT
			ALF_PE ,
			CASE
				WHEN START_DATE < PRE_EVENT_DT THEN PRE_EVENT_DT
				ELSE START_DATE
			END AS NEW_START,
			CASE
				WHEN END_DATE > EVENT_DT THEN EVENT_DT
				ELSE END_DATE
			END AS NEW_END
		FROM
			(
			---------------------------------------------------- start 1.
			SELECT
				ALFS.ALF_PE ,
				EVENT_DT - 1 YEAR AS PRE_EVENT_DT,
				EVENT_DT ,
				GP.START_DATE,
				GP.END_DATE
			FROM
				sailw0826v.BP_2007 AS ALFS
			LEFT JOIN SAIL0826V.WLGP_CLEAN_GP_REG_BY_PRAC_INCLNONSAIL_MEDIAN_20180820 AS GP
					USING (ALF_PE)
			WHERE
				start_date < EVENT_DT
				AND end_date > EVENT_DT - 1 YEAR )
			------------------------------------------------------ end 1. 
)
		------------------------------------------------------ end 2. 
)
	------------------------------------------------------ end 3.
GROUP BY
	ALF_PE ) WITH DATA
	
SELECT * FROM sailw0826v.gp_reg_1yr
SELECT COUNT (DISTINCT ALF_PE) FROM sailw0826v.gp_reg_1yr WHERE SUM_DAYS<364

