SELECT 

a.bnf_code as code, a.nm as term, 

b.BNF_Code, b.BNF_Name, b.SNOMED_Code, b.DMplusD_ProductDescription, 

b.DMplusD__Product_and_PackDescription, b.Pack 

FROM `yhcr-prd-phm-bia-core.CB_MYSPACE_TBK.Opensafely_HTN_meds_ACEi_ARB_CC_Thiazide` a, #this is HTN meds

`yhcr-prd-phm-bia-core.CB_LOOKUPS.tbl_BNF_DMD_SNOMED_lkp` b 

WHERE a.BNF_code = b.BNF_code 

#Save this as a table Final_HTN_meds