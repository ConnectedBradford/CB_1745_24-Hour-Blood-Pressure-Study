SELECT 
    DATE_DIFF(date_of_HTNdiagnosis, Date_GCAPMR_Diagnosis, MONTH) AS months_after_GCA,
    COUNT(person_id) AS num_new_HTN_diagnoses
FROM 
    `yhcr-prd-phm-bia-core.CB_1745.HTN_after_GCAPMR_within2years`
GROUP BY 
    months_after_GCA
ORDER BY 
    months_after_GCA;
