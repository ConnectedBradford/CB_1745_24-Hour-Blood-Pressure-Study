# CB_1745
CB_1745_24-Hour-Blood-Pressure-Study


Scripts are organised into four chunks:

Code lists (scripts beginning 1)
1_1_CB_database_check.R
1_2_codelist_development.R
1_3_codelist_map_readv2.R
1_4_excluded_codelist.R

observations (scripts beginning 2)
2_1_data_linkage_person_BP_bradford.R 
2_2_stat_fall_nofall_ICD.R

cohort creation (scripts beginning 3)
3_1_efi_prepare.R
3_2qrisk_code_check.R

analysis (scripts beginning 4)


## Data linkage and analysis

### 1. Data linkage between patient and AMBP for Bradford

Since 2/12/2025, all of the analyses below are based on CB_1745_BP_NEW rather than CB_1745. Therefore, all related tests include the table name from CB_1745_BP_NEW in parentheses. 

The workflow figures below summarize Sections 1.1 to 1.4.
* The workflow figure for Sections 1.1 to 1.4
<img width="1109" height="594" alt="image" src="https://github.com/user-attachments/assets/63065458-859c-4737-9dca-64c3d6c6daa2" />


* The workflow figure for Sections 1. 4
<img width="980" height="598" alt="image" src="https://github.com/user-attachments/assets/29692ba5-badb-40ce-bb1a-977f4a0e3e6f" />

<img width="841" height="461" alt="image" src="https://github.com/user-attachments/assets/829ab140-efdf-4bed-b7b0-5be27ab240a9" />



***
#### 1.1 Data Linkage Between person and BP24

The dbo.person (updated to dbo.person_ORIGINAL) table contains 19,822 records, half of which are duplicates. After removing the duplicates, 9,911 unique records remain for linkage with dbo.tbl_bloodpressure_data, which contains 2,248,834 records. tbl_bloodpressure_data (updated to dbo.tbl_bloodpressure_data_ORIGINAL) also contains duplicates, with 809,971 unique records.

Following the linkage, a measure_id was generated based on unique combinations of tbl_bloodpressure_data_start_date and person_id_hashed. This process resulted in 12,008 unique measure_ids for BP24 linked data, which refers to 9,408 unique individuals. This linked data have been stored in **CB_1745_BP_NEW.bp24_patient**.

#### 1.2 Extract BP24 Records Measured at Age 65 or Older

BP24 linked records were then filtered to retain only those where the measurement was taken at age 65 or older. The result has been stored in the database as **CB_1745_BP_NEW.dbo.bp_over_65**.

To estimate age at the time of measurement, the difference in days between `bp24_start_date` and `birth_date` was computed and then divided by 365.25 to convert it into years. The divisor 365.25 accounts for leap years, providing a more accurate age estimate than using 365 alone

#### 1.3 Extracting the BP24 Measurement Closest to Age 65 for Each Patient

To extract the BP24 measurement closest to age 65 for each patient, the bp_over_65 dataset was grouped by person_id_hashed. For each patient, the record with the smallest absolute difference between age_at_bp24 and 65 was selected. This produced a subset named bp_closest_65, containing 5,197 unique individuals.

Subsequently, the full BP24 records corresponding to these selected measure_ids were retrieved to form a new dataset, bp24_closest_65, which also included 5,197 unique individuals.

The final dataset at this stage was saved to the database as **CB_1745_BP_NEW.dbo.bp24_closest_65**.

The R codes for above work is **[2_1_data_linkage_person_BP_bradford.R](https://github.com/ConnectedBradford/CB_1745_24-Hour-Blood-Pressure-Study/blob/main/code/2_1_data_linkage_person_BP_bradford.R)**


#### 1.4  Data Cleaning 

##### 1.4.1 Data Updating

- [x] Remove records with complete errors and replace them with the second available measurement

Three patients had all their records marked as errors.** Only one of them has a second available BP24 measurement, taken by the second day after the first failed measurement. Two patients’ records are removed in this step. **5195** left to use

- [x] Add the Time_Period variable, which records whether the BP records were taken during Nighttime (10 pm to 6 am) or Daytime
 
#### 1.4.2 Data Removal

- [x] Remove records where `ErrorStatus` is not `"noerror"`

The remaining 5,195 patients correspond to 348,071 records, of which only 243,147 error-free records are kept for use.

- [x] Remove records that fall outside the acceptable measurement ranges:
  - Systolic Blood Pressure: **50–300 mm Hg**
  - Diastolic Blood Pressure: **30–200 mm Hg**
  - Heart Rate: **30–300 bpm**

` dt[
    Systolic >= 50 & Systolic <= 300 &
      Diastolic >= 30 & Diastolic <= 200 &
      HeartRate >= 30 & HeartRate <= 300]`

There are 64 rows removed (from 243147 to 243083). These cleaned records are saved to the database as **CB_1745_BP_NEW.dbo.bp24_age65**. The unique patient id are stored into **CB_1745_BP_NEW.dbo.bp24_age65_patientid**. T


#### 1.4.3 Data Filtering for Falls and Non-Falls

For the secondary care data (dbo.tbl_diagnosis_snomed_NEW and dbo.tbl_diagnosis_icd_NEW), we first extract the patients of interest based on CB_1745_BP_NEW.dbo.bp24_age65_patientid. We call this extracted result as the aande and  episodes data in the workflow. For each patient, we use bp24_start_date to define a one-year follow-up period (i.e. bp24_plus1yr). The patient and the one-year period after the BP start date are then linked to the corresponding aande and  episodes data based on the person_id_hashed.

The R codes for this section work is **[2_2_stat_fall_nofall_ICD](https://github.com/ConnectedBradford/CB_1745_24-Hour-Blood-Pressure-Study/blob/main/code/2_2_stat_fall_nofall_ICD.R)**
