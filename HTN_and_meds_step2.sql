SELECT 

c.person_id, 

c.Date_GCAPMR_Diagnosis,

c.HTN_diagnosis_date,

d.DMplusD_ProductDescription as name_of_medication, 

d.medicationdosage, 

d.medicationquantity, 

d.datemedicationstart, 

d.datemedicationend, 

d.tbl_srprimarycaremedication_start_date as prescription_date, 

d.tbl_srprimarycaremedication_end_date, 

d.rowidentifier, 

d.dateeventrecorded, 

d.dateevent, 

d.iddoneby, 

d.idorganisationdoneat, 

d.nameofmedication, 

d.issupervised, 

d.superviseddose, 

d.unsuperviseddose, 

d.isrepeatmedication, 

d.isothermedication, 

d.isdentalmedication, 

d.ishospitalmedication, 

d.idorganisation, 

d.idorganisationregisteredat 

  

FROM  

`yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.HTN_before_GCA` c, #change this depending on whether you want before or after GCA/PMR diagnosis

  

(SELECT  

a.code,  

a.term,  

a.SNOMED_Code,  

a.DMplusD_ProductDescription, 

b.person_id, 

b.tbl_srprimarycaremedication_start_date, 

b.tbl_srprimarycaremedication_end_date, 

b.rowidentifier, 

b.dateeventrecorded, 

b.dateevent, 

b.iddoneby, 

b.idorganisationdoneat, 

b.nameofmedication, 

b.datemedicationstart, 

b.datemedicationend, 

b.medicationdosage, 

b.medicationquantity, 

b.issupervised, 

b.superviseddose, 

b.unsuperviseddose, 

b.isrepeatmedication, 

b.isothermedication, 

b.isdentalmedication, 

b.ishospitalmedication, 

b.idorganisation, 

b.idorganisationregisteredat 

  

FROM  

`yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.Final_HTN_meds` a, 

`yhcr-prd-phm-bia-core.CB_FDM_PrimaryCare.tbl_srprimarycaremedication` b 

  

WHERE a.DMplusD_ProductDescription=b.nameofmedication) d 

  

WHERE  

c.person_id = d.person_id 

#Save this as a table e.g. HTN_after_GCA_and_meds_confirmation