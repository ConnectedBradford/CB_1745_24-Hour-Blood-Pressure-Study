select
HTN.person_id,
DOB,
gender,
GCAPMR_Diagnosis,
Date_GCAPMR_Diagnosis,
Age_GCAPMR_Diagnosis,
date_of_HTNdiagnosis,
DATE_DIFF(DATE(HTN.date_of_HTNdiagnosis), PARSE_DATE('%d-%m-%Y', cohort.DOB), YEAR) AS Age_HTN_diagnosis


FROM `yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.Cohort_HTN_before_GCAPMR_MedsuptoGCAdx` HTN
left join `yhcr-prd-phm-bia-core.CB_1745.Final_cohort_v3_extracolumns` as cohort on HTN.person_id = cohort.person_id