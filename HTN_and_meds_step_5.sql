#This will need to be edited depending on what you need but will identify patients who have hypertension code and also a hypertensive med prescribed (within whatever time period you set)

WITH prescription_ranked AS ( 

  SELECT 
    person_id, 
    prescription_date, 
    date_of_HTNdiagnosis,
    name_of_medication,
    ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY prescription_date) AS prescription_rank, 

#Add two conditions - (1) prescription date needs to be after diagnosis date, (2) prescription date should be within 6 months of diagnosis date 

  FROM `yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.HTN_after_GCA_and_meds_confirmation` #change  depending on whether before/after GCA

  WHERE 
    prescription_date >= date_of_HTNdiagnosis
    AND prescription_date <= DATE_ADD(date_of_HTNdiagnosis, INTERVAL 6 MONTH) 
) 

#Select rows where prescription_rank is 1, indicating first prescription for reach patient 

SELECT 

  person_id,
  date_of_HTNdiagnosis,
  prescription_date AS first_HTN_Med_prescription_date, 
  name_of_medication 

FROM prescription_ranked 

WHERE  

prescription_rank = 1 

order by person_id