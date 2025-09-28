WITH 

RankedDiagnoses AS (
    SELECT 
        person_id,
        tbl_srcode_start_date,
        ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY tbl_srcode_start_date) AS diagnosis_rank
    FROM 
        `yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.tbl_srcode`
    WHERE     
    -- These are codes for GCA
    (ctv3code IN ('G755.', 'G7550', 'G755z', 'N200.', 'Nyu41','X00Dy', 'X705l', 'X705m') OR
    -- These are codes for PMR
     ctv3code IN ('XE1FJ', 'X705l', 'N20..'))
    AND tbl_srcode_start_date BETWEEN '2000-01-01' AND '2024-01-01'
)

SELECT DISTINCT
    disease.person_id,
    gender,
    FORMAT_DATE('%Y-%m-%d', DATE(Person.Year_of_birth, Person.month_of_birth, Person.day_of_birth)) AS DOB,
    FORMAT_DATE('%Y-%m-%d', DATE(FIRST_VALUE(RD.tbl_srcode_start_date) OVER (PARTITION BY disease.person_id ORDER BY RD.tbl_srcode_start_date ASC))) AS GCAPMR_diagnosis_date,
    TIMESTAMP_DIFF(RD.tbl_srcode_start_date, DATE(Person.Year_of_birth, Person.month_of_birth, Person.day_of_birth), YEAR) AS GCAPMR_diagnosis_age,
    first_value(ctv3code) over (partition by disease.person_id order by RD.tbl_srcode_start_date asc) ctv3code,
    first_value(ctv3text) over (partition by disease.person_id order by RD.tbl_srcode_start_date asc) ctv3text,
    FORMAT_DATE('%Y-%m-%d', DATE(first_value(tbl_srpatientregistration_start_date) over (PARTITION BY disease.person_id ORDER BY tbl_srpatientregistration_start_date))) AS GP_Registration_Date
  
    

FROM 
`yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.tbl_srpatient` AS Patient

left JOIN `yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.person` AS Person ON Patient.person_id = Person.person_id
left JOIN `yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.tbl_srcode` as Disease on Patient.person_id = Disease.person_id
left JOIN RankedDiagnoses RD ON Patient.person_id = RD.person_id
left JOIN `yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.tbl_srpatientregistration` Reg on Patient.person_id = Reg.person_id

WHERE 
    RD.diagnosis_rank = 1
    AND TIMESTAMP_DIFF(RD.tbl_srcode_start_date, DATE(Person.Year_of_birth, Person.month_of_birth, Person.day_of_birth), YEAR) > 49
    AND
-- These are codes for GCA
    (ctv3code IN ('G755.', 'G7550', 'G755z', 'N200.', 'Nyu41','X00Dy', 'X705l', 'X705m') OR
    -- These are codes for PMR
     ctv3code IN ('XE1FJ', 'X705l', 'N20..'))
    AND Disease.tbl_srcode_start_date BETWEEN '2000-01-01' AND '2023-12-31'
    AND DATE_DIFF(Disease.tbl_srcode_start_date, Reg.tbl_srpatientregistration_start_date, DAY) >183

order by person_id
