# This is the R code to conduct descriptive statistics for the number of patient falls after 1, 2, and 5 years according to the ICD health outcome
#  Bin Chi
#  12/8/2025, update at 2/12/2025

gc()
library(DBI)
library(odbc)
library(data.table)
library(ggplot2)

sql_conn <- tryCatch({DBI::dbConnect(odbc::odbc(),driver = "ODBC Driver 17 for SQL Server", server = "bhts-connectyo3", database = "CB_1745_BP_NEW", Trusted_Connection = "Yes") }, error = function(e) {stop(sprintf("Failded to connect to SQL Server: %s", e$message))}) 


bp24_closest_65 <- dbGetQuery(sql_conn, "SELECT * FROM dbo.bp24_closest_65")
bp_over_65 <- dbGetQuery(sql_conn, "SELECT * FROM dbo.bp_over_65")
setDT(bp24_closest_65)
setDT(bp_over_65)




#For measurements with all error records, remove them and use the second available measurement instead

#statistic by ErrorStatus
gc()
# Replace NA in ErrorStatus with "noerror"
unique(bp24_closest_65$ErrorStatus)


bp24_closest_65[, ErrorStatus := fifelse(is.na(ErrorStatus), "noerror", ErrorStatus)]

# Calculate counts of each ErrorStatus per person
error_counts_person <- bp24_closest_65[, .N, by = .(person_id_hashed, ErrorStatus)]

# Calculate total counts per person
error_counts_person[, total := sum(N), by = person_id_hashed]

# Calculate error rate per ErrorStatus per person
error_counts_person[, rate := N / total]

# View result
head(error_counts_person)

#Example — wide table with counts per error type:

# Wide format for counts (N)
error_counts_wide <- dcast(error_counts_person, 
                           person_id_hashed ~ ErrorStatus, 
                           value.var = "N",
                           fill = 0)  # fill missing with 0

# wide table with rates per error type:

error_rates_wide <- dcast(error_counts_person,
                          person_id_hashed ~ ErrorStatus,
                          value.var = "rate",
                          fill = 0)

setnames(error_rates_wide, 
         old = names(error_rates_wide)[-1], 
         new = paste0(names(error_rates_wide)[-1], "_rate"))

# Merge error_rates_wide and error_counts_wide by person_id_hashed
statistic_errors <- merge(error_rates_wide, error_counts_wide, by = "person_id_hashed", all = TRUE)
head(statistic_errors)

#create a clean function 
clean_bp_closest_65 <- function(statistic_errors_list, 
                                data_over_65, 
                                data_closest65) {
  # Step 1: Identify people who had all errors in their first measurement after age 65
  error_ids <- statistic_errors_list[noerror == 0, unique(person_id_hashed)]
  
  # Step 2: For each of those people, get their rows from data_over_65
  update_data <- data_over_65[person_id_hashed %in% error_ids]
  
  # Step 3: Rank unique measure_ids per person by bp24_start_date
  measure_rank <- update_data[, .(bp24_start_date = min(bp24_start_date)), 
                              by = .(person_id_hashed, measure_id)][
                                order(person_id_hashed, bp24_start_date)
                              ][, rn := seq_len(.N), by = person_id_hashed]
  
  # Step 4: Assign rn to every row in update_data
  update_data <- merge(update_data, measure_rank, 
                       by = c("person_id_hashed", "measure_id"), 
                       all.x = TRUE)
  
  # Step 5: Remove first errored measure from data_closest65
  data_filtered <- data_closest65[!(person_id_hashed %in% error_ids)]
  
  # Step 6: Get second measure_id per person with rn == 2
  second_measures <- update_data[rn == 2,
                                 .(person_id_hashed, second_measure_id = measure_id)]
  
  # Step 7: Extract second measurement rows from data_over_65
  update_rows <- data_over_65[
    person_id_hashed %in% second_measures$person_id_hashed & 
      measure_id %in% second_measures$second_measure_id
  ]
  
  
  # Step 8: Bind filtered + updated rows
  data_closest65_clean <- rbind(data_filtered, update_rows, use.names = TRUE, fill = TRUE)
  
  
  return(data_closest65_clean)
}



dim(bp24_closest_65)
#348034     36
length(unique(bp24_closest_65$person_id_hashed))
#5197

uniqueN(bp_over_65$measure_id)
# 6511
uniqueN(bp24_closest_65$measure_id)
# 5197

bp24_closest_65_clean1<-clean_bp_closest_65(statistic_errors,bp_over_65 ,bp24_closest_65)

dim(bp24_closest_65_clean1)
#348071     
length(unique(bp24_closest_65_clean1$person_id_hashed))
#5195
uniqueN(bp24_closest_65_clean1$measure_id)
#5195
#Two patient records were moved in the above stage because their first blood pressure measurements
#contained only errors, and a second measurement was unavailable afterward.


# Update the error status
bp24_closest_65_clean1[, ErrorStatus := fifelse(is.na(ErrorStatus), "noerror", ErrorStatus)]
unique(bp24_closest_65_clean1$ErrorStatus)
#"noerror"   "RecorderIndicatedError" "OutwithValidityRanges"  "ManualEdit"
dim(bp24_closest_65_clean1)
#348071 30
bp24_closest_65_clean1<-bp24_closest_65_clean1[bp24_closest_65_clean1$ErrorStatus=="noerror",    ]
dim(bp24_closest_65_clean1)
#243147 30

bp24_closest_65_clean1[, Systolic := as.integer(Systolic)]
bp24_closest_65_clean1[, Diastolic := as.integer(Diastolic)]
bp24_closest_65_clean1[, HeartRate := as.integer(HeartRate)]

# Function to clean based on given ranges
clean_data <- function(dt, name) {
  initial_rows <- nrow(dt)
  dt_clean <- dt[
    Systolic >= 50 & Systolic <= 300 &
      Diastolic >= 30 & Diastolic <= 200 &
      HeartRate >= 30 & HeartRate <= 300
  ]
  final_rows <- nrow(dt_clean)
  cat(sprintf("'%s': %d rows removed (from %d to %d)\n", name, initial_rows - final_rows, initial_rows, final_rows))
  return(dt_clean)
}

# Clean with reporting
bp24_closest_65_clean <- clean_data(bp24_closest_65_clean1, "bp24_closest_65_clean1")
#'bp24_closest_65_clean1':  64 rows removed (from 243147 to 243083)

dim(bp24_closest_65_clean)
#243083
uniqueN(bp24_closest_65_clean$person_id_hashed)
#5195
uniqueN(bp24_closest_65_clean$measure_id)
#5195

rm(bp24_closest_65_clean1,bp24_closest_65)

#rm(bp_over_65)
# Write the filtered data frame to the database table bp24_age65
DBI::dbWriteTable(
  conn = sql_conn,
  name = DBI::Id(schema = "dbo", table = "bp24_age65"),
  value = bp24_closest_65_clean,
  overwrite = TRUE
)

bp24_closest_65_clean <- dbGetQuery(sql_conn, "SELECT * FROM dbo.bp24_age65")

library(data.table)
setDT(bp24_closest_65_clean)
person_ids <- unique(bp24_closest_65_clean[, .(person_id_hashed)])

#Write the filtered data frame to the database table bp24_age65
DBI::dbWriteTable(
  conn = sql_conn,
  name = DBI::Id(schema = "dbo", table = "bp24_age65_patientid"),
  value = person_ids,
  overwrite = TRUE
)

setDT(person_ids)

dim(person_ids)
#5195    1

##########get the age and sex for abstract###############
head(bp24_closest_65_clean)

statistic_population <- bp24_closest_65_clean[, .(
  person_id_hashed,
  age_at_bp24,
  birth_date,
  bp24_start_date
)]
dim(statistic_population)
statistic_population<-unique(statistic_population)
dim(statistic_population)
#5195    4

person <- dbGetQuery(sql_conn, "SELECT person_id_hashed,gender_source_value FROM dbo.person_ORIGINAL")
dim(person)

dim(person)
person<-unique(person)
dim(person)
#9911    2

person<-person[person$person_id_hashed %in%  statistic_population$person_id_hashed,]
dim(person)
#5195    2

##see https://digital.nhs.uk/data-and-information/data-collections-and-data-sets/data-sets/mental-health-services-data-set/submit-data/data-quality-of-protected-characteristics-and-other-vulnerable-groups/gender-identity
unique(person$gender_source_value)

setDT(person)
person[, gender := fcase(
  gender_source_value %in% c("F","Female","female","2"), "F",
  gender_source_value %in% c("M","Male","male","1"), "M",
  default = NA_character_
)]

head(person)
dim(statistic_population)
#5195    4
statistic_population<-merge(statistic_population,person,by="person_id_hashed")
dim(statistic_population)
#5195    6

head(statistic_population)

#statistic_population[, mean_age := mean(age_at_bp24, na.rm = TRUE)]
cc<-as.data.frame(unique(statistic_population$age_at_bp24))
rm(cc)

#no missing value in gender

statistic_population[, mean(age_at_bp24, na.rm = TRUE)]
#77.63303

statistic_population[, .(
  mean = mean(age_at_bp24, na.rm = TRUE),
  sd   = sd(age_at_bp24, na.rm = TRUE),
  cv   = sd(age_at_bp24, na.rm = TRUE) / mean(age_at_bp24, na.rm = TRUE)
)]
# mean       sd         cv
# <num>    <num>      <num>
#   1: 77.63303 7.246052 0.09333724

library(ggplot2)

dev.new()
# Plot the distribution with average lines

dev.new()
ggplot(statistic_population, aes(x = age_at_bp24)) +
  geom_histogram(
    aes(y = ..density..),   # match density scale
    binwidth = 1,
    fill = "steelblue",
    color = "black",
    na.rm = TRUE
  ) +
  geom_density(
    color = "red",
    linewidth = 1,
    alpha = 0.3,
    na.rm = TRUE
  ) +
  labs(
    title = "Age Distribution",
    x = "Age",
    y = "Density"
  ) +
  scale_x_continuous(
    breaks = seq(65, 110, by =5)
  ) +
  theme_minimal()+
  theme(
    axis.title = element_text(size=14), 
    axis.text = element_text(size=14),
    strip.text.x = element_text(size=14),
    strip.text.y = element_text(size=14),
    legend.text = element_text(size=14),
    legend.title = element_text(size=14),
    axis.title.y.left = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)),
    axis.title.y.right = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10))
  )



ggsave("U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/plot/age_histogram.jpg",units="in", width=10, height=5.5, dpi=500)


statistic_population[, .N, by = gender]

# gender      N
#M  2176
#  F  2984
# <NA>    35

dim(statistic_population[!is.na(gender), ])
#5160
statistic_population[!is.na(gender), 
                     mean(age_at_bp24, na.rm = TRUE)]

#77.63522


statistic_population[!is.na(gender), .(
  mean = mean(age_at_bp24, na.rm = TRUE),
  sd   = sd(age_at_bp24, na.rm = TRUE),
  cv   = sd(age_at_bp24, na.rm = TRUE) / mean(age_at_bp24, na.rm = TRUE)
)]
# 
# mean      sd         cv
# <num>   <num>      <num>
#   1: 77.63522 7.23576 0.09320202


statistic_population[!is.na(gender), 
                     .(count = .N,
                       mean_age = mean(age_at_bp24, na.rm = TRUE)), 
                     by = gender]

# gender count mean_age
# 
#  M  2176 76.70269
#  F  2984 78.31525


dev.new()
ggplot(statistic_population[!is.na(gender), ], aes(x = age_at_bp24)) +
  geom_histogram(
    aes(y = ..density..),   # match density scale
    binwidth = 1,
    fill = "steelblue",
    color = "black",
    na.rm = TRUE
  ) +
  geom_density(
    color = "red",
    linewidth = 1,
    alpha = 0.3,
    na.rm = TRUE
  ) +
  labs(
    title = "Age Distribution(remove 35 data with no gender)",
    x = "Age",
    y = "Density"
  ) +
  scale_x_continuous(
    breaks = seq(65, 110, by =5)
  ) +
  theme_minimal()+
  theme(
    axis.title = element_text(size=14), 
    axis.text = element_text(size=14),
    strip.text.x = element_text(size=14),
    strip.text.y = element_text(size=14),
    legend.text = element_text(size=14),
    legend.title = element_text(size=14),
    axis.title.y.left = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)),
    axis.title.y.right = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10))
  )



ggsave("U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/plot/age_histogram_removeunknowgender.jpg",units="in", width=10, height=5.5, dpi=500)


################healthoutcome in secondary care###########################

#######fall or not fall based on tbl_AandE and tbl_episode
# By the end of Jan 2026, the secondary care are supplied by coding scheme, which are dbo.tbl_diagnosis_snomed_NEW and dbo.tbl_diagnosis_icd_NEW

aande<- dbGetQuery(sql_conn, "SELECT * FROM dbo.tbl_diagnosis_snomed_NEW")
episode<- dbGetQuery(sql_conn, "SELECT * FROM dbo.tbl_diagnosis_icd_NEW")


dim(aande)
#8047   11
length(unique(aande$person_id_hashed))
#3267
aande<-unique(aande)
dim(aande)
#8047   11


dim(episode)
#1066064      11
length(unique(episode$person_id_hashed))
#8820
episode<-unique(episode)
dim(episode)
#1066064      11
gc()


dim(person_ids[(person_ids$person_id_hashed %in% aande$person_id_hashed) |(person_ids$person_id_hashed  %in% episode$person_id_hashed)])
#4720

#old data with old statistic
#dim(person_ids[(person_ids$person_id_hashed %in% aande1$person_id_hashed) |(person_ids$person_id_hashed  %in% episode1$person_id_hashed)])
#4699    1


# aande1<- dbGetQuery(sql_conn, "SELECT * FROM dbo.tbl_aAnde_ORIGINAL")
# episode1<- dbGetQuery(sql_conn, "SELECT * FROM dbo.tbl_episode_ORIGINAL")

#below the records for old primary care and secondary care data
# dim(aande)
# #123952     23
# length(unique(aande$person_id_hashed))
# #8342
#aande1<-unique(aande1)
# dim(aande)
# #61561    23


# dim(episode)
# #394412     19
# length(unique(episode$person_id_hashed))
# #6998
#episode1<-unique(episode1)
# dim(episode)
# #109475     19
# gc()
setDT(episode)
setDT(aande)

# ---- Filter to only the patients of interest ----
filter_patients <- function(dt, ids) {
  # ensure input is data.table
  setDT(dt)
  
  # filter rows
  dt <- dt[person_id_hashed %in% ids$person_id_hashed]
  
  # diagnostics
  message("Rows: ", nrow(dt))
  message("Unique patients: ", uniqueN(dt$person_id_hashed))
  
  return(dt) 
}

aande   <- filter_patients(aande, person_ids)
#new
#Rows: 4817
#Unique patients: 1825

#old data with old statistic
#Rows: 32510
#Unique patients: 4507
episode <- filter_patients(episode, person_ids)
#new
# Rows: 677778
# Unique patients: 4717

#old data with old statistic
#Rows: 63899
#Unique patients: 3998
#####indentify time period of the secondary care data##########
head(episode)

#START_DATE in dbo.tbl_diagnosis_icd_NEW
max(episode$START_DATE)
min(episode$START_DATE)

tt<-as.data.frame(unique(episode$START_DATE))

dates <- tt[,1]

# Remove NA values
dates_clean <- dates[!is.na(dates)]

# Get min and max
min_val <- min(dates_clean)
max_val <- max(dates_clean)

min_val
max_val

# "2008-04-05"
#"2025-12-15"
sum(is.na(episode$START_DATE))
#0
rm(tt,dates, min_val, max_val,dates_clean)

head(aande)

#START_DATE in dbo.tbl_diagnosis_icd_NEW
max(aande$START_DATE)
#"2024-12-27"
min(aande$START_DATE)
#"2017-09-23"
tt<-as.data.frame(unique(aande$START_DATE))

dates <- tt[,1]

# Remove NA values
dates_clean <- dates[!is.na(dates)]

# Get min and max
min_val <- min(dates_clean)
max_val <- max(dates_clean)

min_val
max_val

# "2017-09-23"
#"2024-12-27"
sum(is.na(aande$START_DATE))
#0
rm(tt,dates, min_val, max_val,dates_clean)



###################
# gc()
# t1<-as.data.frame(unique(unique(aande$person_id_hashed)))
# t2<-as.data.frame(unique(unique(episode$person_id_hashed)))
# colnames(t1)<-"person_id_hashed"
# colnames(t2)<-"person_id_hashed"
# tt<-rbind(t1,t2)
# dim(tt)
# tt<-unique(tt)
# dim(tt)
# #4720    
# rm(tt,t1,t2)
###################

#extract the falls based on the fall code
#head(bp24_closest_65_clean)

#  birth_date derived from birth_datetime in dbo.person. extract person_id_hashed,birthdate and bp24_start_date for health outcome


person_birth <- unique(
  bp24_closest_65_clean[, .(person_id_hashed, birth_date, bp24_start_date)]
)
str(person_birth)
library(lubridate)
#add in bp24_plus1yr 
person_birth[, bp24_plus1yr := bp24_start_date %m+% years(1)]
#person_birth[, bp24_plus2yr := bp24_start_date %m+% years(2)]
#person_birth[, bp24_plus5yr := bp24_start_date %m+% years(5)]
head(person_birth)

# join birth, bp24 date info with the diagnosis datasets
aande   <- merge(aande,   person_birth, by = "person_id_hashed")
episode <- merge(episode, person_birth, by = "person_id_hashed")
#new
dim(aande)
#4817   17
dim(episode)
#  677778     17

#old data with old statistic
# dim(aande)
# #32510    28
# dim(episode)
# # 63899    24
#for both, extract the part 

head(aande)
head(episode)
#tbl_aAndE_start_date

# aande[, ae_start_date := as.Date(tbl_aAndE_start_date)]
# 
# episode[, episode_start_date := as.Date(episode_start_date)]
# #

# Create a start date for the diagnosis
aande[, ae_start_date := as.Date(START_DATE )]
episode[, episode_start_date := as.Date(START_DATE )]
#

dim(
  person_birth[person_id_hashed %in% union(aande$person_id_hashed,
                                           episode$person_id_hashed)]
)
#new: 4720    6


#old data with old statistic
#4699    
#there are 4699 has diagnoses informaiton in aande and episodes

# extract diagnoses between bp24_start_date and one year after
setDT(aande)
setDT(episode)

# aande_clean2 <- aande[ae_start_date >= bp24_start_date & ae_start_date < bp24_plus2yr]
# episode_clean2 <- episode[episode_start_date >= bp24_start_date & episode_start_date < bp24_plus2yr]
# 
# aande_clean5 <- aande[ae_start_date >= bp24_start_date & ae_start_date < bp24_plus5yr]
# episode_clean5 <- episode[episode_start_date >= bp24_start_date & episode_start_date < bp24_plus5yr]

aande_clean <- aande[ae_start_date >= bp24_start_date & ae_start_date < bp24_plus1yr]
episode_clean <- episode[episode_start_date >= bp24_start_date & episode_start_date < bp24_plus1yr]

# check unique number of patients afterwards
uniqueN(aande$person_id_hashed)
# 1825
uniqueN(episode$person_id_hashed)
#4717



# dim(aande_clean)
# #2879 
# dim(episode_clean)
# #6595 


dim(aande_clean)
#457  17
dim(episode_clean)
#61019    17

uniqueN(aande_clean$person_id_hashed)
#267
uniqueN(episode_clean$person_id_hashed)
# 2121

# dim(aande_clean2)
# #809
# dim(episode_clean2)
# # 115261     

# 
# uniqueN(aande_clean2$person_id_hashed)
# # new 425
# uniqueN(episode_clean2$person_id_hashed)
# # new 2821

# # check dimensions
# uniqueN(aande$person_id_hashed)
# #4507
# uniqueN(episode$person_id_hashed)
# #3998
# 
# 
# 
# dim(aande_clean)
# #2879 
# dim(episode_clean)
# #6595 
# 
# uniqueN(aande_clean$person_id_hashed)
# #1455
# uniqueN(episode_clean$person_id_hashed)
# #1125




# dim(aande_clean2)
# #5327 
# dim(episode_clean2)
# # 11381

# uniqueN(aande_clean2$person_id_hashed)
# #2096
# uniqueN(episode_clean2$person_id_hashed)
# #1621


# dim(aande_clean5)
# #11652
# dim(episode_clean5)
# #24047
# 
# uniqueN(aande_clean5$person_id_hashed)
# #3097
# uniqueN(episode_clean5$person_id_hashed)
# # 2448
# 


dim(
  person_birth[person_id_hashed %in% union(aande_clean$person_id_hashed,
                                           episode_clean$person_id_hashed)]
)
#new 2136    6
#1907

# dim(
#   person_birth[person_id_hashed %in% union(aande_clean2$person_id_hashed,
#                                            episode_clean2$person_id_hashed)]
# )
# #2837    6
# #old 2586
# 
# dim(
#   person_birth[person_id_hashed %in% union(aande_clean5$person_id_hashed,
#                                            episode_clean5$person_id_hashed)]
# )
# # 3509

dim(aande_clean)
#457  17
dim(episode_clean)
#61019    17

DBI::dbWriteTable(
  conn = sql_conn,
  name = DBI::Id(schema = "dbo", table = "bp24_diag_sct_clean"),
  value = aande_clean,
  overwrite = TRUE
)
DBI::dbWriteTable(
  conn = sql_conn,
  name = DBI::Id(schema = "dbo", table = "bp24_diag_icd_clean"),
  value = episode_clean,
  overwrite = TRUE
)

########extract the diagnose with one year of the BP Reading##############

#####################################
# get all columns that start with "diagnosis"

# some basic check
head(aande_clean) 
#DIAG_CODE 

unique(nchar(aande_clean$DIAG_CODE))
# 9 15 16 12 14  8  7


head(episode_clean)
#DIAG_CODE, icd

unique(nchar(episode_clean$DIAG_CODE))
#4 5 3
sort(unique(substr(aande_clean$DIAG_CODE , 1, 1)))
#"1" "2" "3" "4" "5" "7" "8" "9"

episode_clean_not4 <- episode_clean[
  nchar(episode_clean$DIAG_CODE) != 4, 
]

werid_icd<-as.data.frame(unique(episode_clean_not4$DIAG_CODE))
colnames(werid_icd)<-"DIAG_CODE"
head(werid_icd)
unique(substr(werid_icd$DIAG_CODE , 1, 1))
#"A" "D" "E" "F" "G" "H" "I" "J" "M" "R" "S" "T"
setDT(werid_icd)
setorder(werid_icd, DIAG_CODE)


fwrite(werid_icd,"U:/Academic Unit - Bradford 24BP/CB/1Data_dictionary_ingestion/Connect_Braford/data_issue/werid_icd_3_5.csv")


rm(episode_clean_not4)

####formal start

falls_ICD10<-fread("U:/Academic Unit - Bradford 24BP/CB/2codelist/BP24_codelist/202510/ICD10_falls_102026.csv")
dim(falls_ICD10)
#177   8
unique(substr(falls_ICD10$icd10_code , 1, 1))
# R or W
head(falls_ICD10)

falls_ICD10[grepl("^R",falls_ICD10$icd10_code),]
#R296   
#unique(falls_ICD10$icd10_4)


# head(episode_clean)
# R_w_icd <- as.data.frame(unique(episode_clean[grepl("^R|^w", episode_clean$DIAG_CODE ), ]$DIAG_CODE))
# colnames(R_w_icd)<-"DIAG_CODE"
# R_w_icd[
#   nchar(R_w_icd$DIAG_CODE) != 4, 
# ]

#"R69" "R99"


falls_sct_all<-fread("U:/Academic Unit - Bradford 24BP/CB/2codelist/BP24_codelist/202510/SCT_falls_102026.csv")
dim(falls_sct_all)

# new #827 8
#831   9


# head(episode_clean)
# head(falls_ICD10)
# tt<-episode_clean[DIAG_CODE %in% falls_ICD10$icd10_4  ,]
# tt<-episode_clean[grepl("R|W",substr(tt$DIAG_CODE , 1, 1)),]
# 
# sort(unique(substr(tt$DIAG_CODE , 1, 1)))

episode_filtered <- episode_clean[DIAG_CODE %in% falls_ICD10$icd10_4  ,]
dim(episode_filtered)
#1391
uniqueN(episode_filtered$person_id_hashed)
#363

head(falls_sct_all)

falls_sct_all$sct<- gsub("'", "", falls_sct_all$code1)

head(aande_clean)


aande_filtered <- aande_clean[
  DIAG_CODE %in% falls_sct_all$sct
]
dim(aande_filtered)
#1
uniqueN(aande_filtered$person_id_hashed)
#1

unique(episode_filtered[episode_filtered$person_id_hashed %in% aande_filtered$person_id_hashed,  ]$person_id_hashed)
#C6FD1D7A44818AD8EA9FCFA30CFE77B971C7F76B852601098D76D17468AE239D


patient_id_counts <- function(dt1, dt2, id_col = "person_id_hashed") {
  setDT(dt1)
  setDT(dt2)
  
  ids1 <- unique(dt1[[id_col]])
  ids2 <- unique(dt2[[id_col]])
  
  list(
    unique_in_sct   = length(ids1),
    unique_in_icd   = length(ids2),
    common_in_both  = length(intersect(ids1, ids2)),
    total_unique    = length(union(ids1, ids2))
  )
}

# Example usage
counts <- patient_id_counts(aande_filtered, episode_filtered)
print(counts)

# $unique_in_sct
# [1] 1
# 
# $unique_in_icd
# [1] 363
# 
# $common_in_both
# [1] 1
# 
# $total_unique
# [1] 363



combined_unique_ids <- unique(c(
  episode_filtered$person_id_hashed,
  aande_filtered$person_id_hashed
))

head(combined_unique_ids)
combined_unique_ids<-unique(combined_unique_ids)
length(combined_unique_ids)
#363

####################fall vs no-fall group#######################
head(episode_filtered)
head(aande_filtered)
# select column personid and start date
data1_long <- aande_filtered[, .(person_id_hashed, ae_start_date)]
data2_long <- episode_filtered[, .(person_id_hashed, episode_start_date)]

# rename column in data1 for consistency
setnames(data1_long, "ae_start_date", "episode_start_date")

# combine and keep unique rows
ICD_fall_1yr_long <- unique(rbind(data1_long, data2_long))

# count unique persons
uniqueN(ICD_fall_1yr_long$person_id_hashed)
#363

# view first few rows
head(ICD_fall_1yr_long)
dim(ICD_fall_1yr_long)
#777

ICD_fall_1yr_earliest <- ICD_fall_1yr_long[, .(episode_start_date = min(episode_start_date)), by = person_id_hashed]
dim(ICD_fall_1yr_earliest)
#363
uniqueN(ICD_fall_1yr_earliest$person_id_hashed)
#363
DBI::dbWriteTable(
  conn = sql_conn, 
  name = DBI::Id(schema = "dbo", table = "bp24_fall_1yr_363"), 
  value = ICD_fall_1yr_earliest, 
  overwrite = TRUE
)


#######statistic for fall and no falls###
health_outcome_ICD<-dbGetQuery(sql_conn, "SELECT * FROM dbo.bp24_fall_1yr_363")


dim(health_outcome_ICD)
#363
names(health_outcome_ICD)
#"person_id_hashed"   "episode_start_date"
setDT(health_outcome_ICD)
head(health_outcome_ICD)
uniqueN(health_outcome_ICD$person_id_hashed)
#363


health_outcome_ICD<-unique(health_outcome_ICD)
dim(health_outcome_ICD)
#363

head(bp24_closest_65_clean)
bp24_closest_65_clean[, Time_Day_num := as.numeric(as.character(Time_Day))]

# Now create Time_combined
bp24_closest_65_clean[, Time_combined := Time_Day_num * 24 + as.numeric(as.character(Time_Hour)) + as.numeric(as.character(Time_Minute)) / 60]


#reate a new variable that classifies each record in your dt_plot data.table as either being within the 10 PM–6 AM period (overnight) or the 6 AM–10 PM period (daytime)
bp24_closest_65_clean[, Time_Period := ifelse(
  as.numeric(as.character(Time_Hour)) >= 22 | as.numeric(as.character(Time_Hour)) < 6, 
  "Nighttime", 
  "Daytime"
)]

#keep the useful varaible
names(bp24_closest_65_clean)


#select useful columns
# [1] "person_id_hashed"                  "tbl_bloodpressure_data_start_date" "tbl_bloodpressure_data_end_date"   "filename"                         
# [5] "Time_Day"                          "Time_Hour"                         "Time_Minute"                       "Time_Second"                      
# [9] "ReadingStatus"                     "ErrorStatus"                       "Systolic"                          "Diastolic"                        
# [13] "MeanArterialPressure"              "HeartRate"                         "PulsePressure"                     "CoefficientOfVariability"         
# [17] "DiaryEventAnnotation"              "Excluded"                          "Time"                              "PatientNumber"                    
# [21] "found_using"                       "cb_date_added"                     "cb_datasetref"                     "measure_id"                       
# [25] "year_of_birth"                     "death_datetime"                    "birth_datetime"                    "birth_date"                       
# [29] "bp24_start_date"                   "age_at_bp24"                       "Time_Day_num"                      "Time_combined"                    
# [33] "Time_Period"

#removed fields
#unique(bp24_closest_65_clean$filename)
# "<raw>"
unique(bp24_closest_65_clean$CoefficientOfVariability)
#0
unique(bp24_closest_65_clean$found_using)
# "patient_number"                            "patient_number WITHOUT PREFIX RAE"         "patient_number WITHOUT PREFIX RAE & add 0" "patient_number REPLACING MRN with RAE"  
unique(bp24_closest_65_clean$cb_date_added)
#"2024-09-06 16:42:59"
unique(bp24_closest_65_clean$cb_datasetref)
#tmp_Clinical_Big_20240906

#check the Time_combined and Time_Period
View(bp24_closest_65_clean)
bp24_closest_65_clean <- bp24_closest_65_clean[, .(
  person_id_hashed,
  tbl_bloodpressure_data_start_date,
  tbl_bloodpressure_data_end_date,
  Time_Day,
  Time_Hour,
  Time_Minute,
  Time_Second,
  ReadingStatus,
  ErrorStatus,
  Systolic,
  Diastolic,
  MeanArterialPressure,
  HeartRate,
  PulsePressure,
 # CoefficientOfVariability,
  measure_id,
  death_datetime,
  birth_datetime,
  birth_date,
  bp24_start_date,
  age_at_bp24,
  Time_combined,
  Time_Period
)]


dim(bp24_closest_65_clean)
##243083 22




BPdata_ICD_year1_nofall <- bp24_closest_65_clean[!(bp24_closest_65_clean$person_id_hashed %in% health_outcome_ICD$person_id_hashed),]
dim(BPdata_ICD_year1_nofall)
#227763     22
uniqueN(BPdata_ICD_year1_nofall$person_id_hashed)
#4832

BPdata_ICD_year1_fall <- bp24_closest_65_clean[bp24_closest_65_clean$person_id_hashed %in% health_outcome_ICD$person_id_hashed,]
dim(BPdata_ICD_year1_fall)
# 15320    22
uniqueN(BPdata_ICD_year1_fall$person_id_hashed)
#363

uniqueN(BPdata_ICD_year1_fall$person_id_hashed)/uniqueN(bp24_closest_65_clean$person_id_hashed)
#0.06987488

uniqueN(bp24_closest_65_clean$person_id_hashed)
#5195
uniqueN(BPdata_ICD_year1_nofall$person_id_hashed)+uniqueN(BPdata_ICD_year1_fall$person_id_hashed)
#5195
gc()



uniqueN(bp24_closest_65_clean$person_id_hashed)
#5195
uniqueN(bp24_closest_65_clean$person_id_hashed)-uniqueN(BPdata_ICD_year1_fall$person_id_hashed)
#4832


DBI::dbWriteTable(sql_conn, 
                  name = DBI::Id(schema = "dbo", table = "bp24data_year1_nofall"), 
                  value = BPdata_ICD_year1_nofall, 
                  overwrite = TRUE)  

DBI::dbWriteTable(sql_conn, 
                  name = DBI::Id(schema = "dbo", table = "bp24data_year1_fall"), 
                  value = BPdata_ICD_year1_fall,
                  overwrite = TRUE) 


#Combine Time_Hour and Time_Minute into a time in hours (as numeric), and flag if it's within ±30 minutes of an integer hour
setDT(BPdata_ICD_year1_fall)
setDT(BPdata_ICD_year1_nofall)

assign_hour_from_time_new <- function(dt, hour_col = "Time_Hour", minute_col = "Time_Minute", new_col = "Hour") {
  if (!data.table::is.data.table(dt)) {
    stop("Input must be a data.table.")
  }
  
  if (!all(c(hour_col, minute_col) %in% names(dt))) {
    stop("Specified hour and minute columns not found in the data.table.")
  }
  
  dt[, c(hour_col, minute_col) := lapply(.SD, function(x) as.numeric(as.character(x))),
     .SDcols = c(hour_col, minute_col)]
  
  # Round fractional hour and wrap 24 to 0
  dt[, (new_col) := round(get(hour_col) + get(minute_col) / 60) %% 24]
  
  return(dt)
}

BPdata_ICD_year1_fall <- assign_hour_from_time_new(BPdata_ICD_year1_fall)
BPdata_ICD_year1_nofall <- assign_hour_from_time_new(BPdata_ICD_year1_nofall)


sort(unique(BPdata_ICD_year1_fall$Hour))
# 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
sort(unique(BPdata_ICD_year1_nofall$Hour))
# 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23

add_age_band <- function(dt) {
  # Define labels
  age_labels <- c(
    "65–69", "70–74", "75–79", "80–84", "85–89",
    "90–94", "95–99", "100+"
  )
  
  # Generate band as character vector first
  dt[, age_band_5yr := ifelse(
    age_at_bp24 >= 100,
    "100+",
    as.character(cut(
      age_at_bp24,
      breaks = seq(65, 100, by = 5),
      right = FALSE,
      include.lowest = TRUE,
      labels = age_labels[1:7]
    ))
  )]
  
  # Convert to ordered factor
  dt[, age_band_5yr := factor(age_band_5yr, levels = age_labels, ordered = TRUE)]
}

# Then, apply add_age_band (function already defined earlier)
add_age_band(BPdata_ICD_year1_fall)
add_age_band(BPdata_ICD_year1_nofall)

sort(unique(BPdata_ICD_year1_fall$age_band_5yr))
#65–69 70–74 75–79 80–84 85–89 90–94 95–99 100+ 
sort(unique(BPdata_ICD_year1_nofall$age_band_5yr))
#65–69 70–74 75–79 80–84 85–89 90–94 95–99 100+ 

View(BPdata_ICD_year1_nofall)

#############SPB statis##############
calculate_sbp_dipping <- function(dt) {
  required_cols <- c("Systolic", "Time_Period", "person_id_hashed")
  missing_cols <- setdiff(required_cols, names(dt))
  if (length(missing_cols) > 0) {
    stop(paste("Missing columns:", paste(missing_cols, collapse = ", ")))
  }
  
  
  sbp_avg <- dt[, .(avg_systolic = mean(Systolic, na.rm = TRUE)),
                by = .(person_id_hashed, Time_Period)]
  
  # Reshape to wide format with 'Daytime' and 'Nighttime'
  sbp_wide <- dcast(sbp_avg, person_id_hashed ~ Time_Period, value.var = "avg_systolic")
  
  # Compute dipping: (Daytime - Nighttime) / Daytime; NA if missing
  sbp_wide[, sbp_dipping := fifelse(
    !is.na(Daytime) & !is.na(Nighttime),
    (Daytime - Nighttime) / Daytime,
    NA_real_
  )]
  
  # Return person_id, Daytime, Nighttime, and dipping
  return(sbp_wide[, .(person_id_hashed, Daytime, Nighttime, sbp_dipping)])
}

# person_id_hashed  Daytime Nighttime sbp_dipping

fall_year1_dipping<-calculate_sbp_dipping(BPdata_ICD_year1_fall)
nonfall_year1_dipping<-calculate_sbp_dipping(BPdata_ICD_year1_nofall)

###############T test Part#####################
#T test for fall, no fall on SBP-dipping

t.test(
  na.omit(BPdata_ICD_year1_fall$Systolic),
  na.omit(BPdata_ICD_year1_nofall$Systolic),
  alternative = "two.sided",
  var.equal = FALSE
)


# Welch Two Sample t-test
# 
# data:  na.omit(BPdata_ICD_year1_fall$Systolic) and na.omit(BPdata_ICD_year1_nofall$Systolic)
# t = 1.0748, df = 17188, p-value = 0.2825
# alternative hypothesis: true difference in means is not equal to 0
# 95 percent confidence interval:
#   -0.1803808  0.6183879
# sample estimates:
#   mean of x mean of y 
# 133.2661  133.0471 


#T test for fall, no fall on SBP at day time

t.test(
  na.omit(BPdata_ICD_year1_fall[BPdata_ICD_year1_fall$Time_Period=="Daytime",]$Systolic),
  na.omit(BPdata_ICD_year1_nofall[BPdata_ICD_year1_nofall$Time_Period=="Daytime",]$Systolic),
  alternative = "two.sided",
  var.equal = FALSE
)

# Welch Two Sample t-test
# 
# data:  na.omit(BPdata_ICD_year1_fall[BPdata_ICD_year1_fall$Time_Period == "Daytime", ]$Systolic) and na.omit(BPdata_ICD_year1_nofall[BPdata_ICD_year1_nofall$Time_Period == "Daytime", ]$Systolic)
# t = -1.0326, df = 13959, p-value = 0.3018
# alternative hypothesis: true difference in means is not equal to 0
# 95 percent confidence interval:
#   -0.6707841  0.2079074
# sample estimates:
#   mean of x mean of y 
# 134.0608  134.2923 



t.test(
  na.omit(BPdata_ICD_year1_fall[BPdata_ICD_year1_fall$Time_Period=="Nighttime",]$Systolic),
  na.omit(BPdata_ICD_year1_nofall[BPdata_ICD_year1_nofall$Time_Period=="Nighttime",]$Systolic),
  alternative = "two.sided",
  var.equal = FALSE
)

# Welch Two Sample t-test
# 
# data:  na.omit(BPdata_ICD_year1_fall[BPdata_ICD_year1_fall$Time_Period == "Nighttime", ]$Systolic) and na.omit(BPdata_ICD_year1_nofall[BPdata_ICD_year1_nofall$Time_Period == "Nighttime", ]$Systolic)
# t = 5.2258, df = 3212.3, p-value = 1.845e-07
# alternative hypothesis: true difference in means is not equal to 0
# 95 percent confidence interval:
#   1.572141 3.460279
# sample estimates:
#   mean of x mean of y 
# 129.7980  127.2818 

#T-test for fall and no falls in term of number of SBP records lower than 100 

fall_counts <- BPdata_ICD_year1_fall[, .(count_low = sum(Systolic < 100, na.rm = TRUE)), by =  person_id_hashed]$count_low
nofall_counts <- BPdata_ICD_year1_nofall[, .(count_low = sum(Systolic < 100, na.rm = TRUE)), by =  person_id_hashed]$count_low

# t-test on counts
t.test(
  fall_counts,
  nofall_counts,
  alternative = "two.sided",
  var.equal = FALSE
)

# Welch Two Sample t-test
# 
# data:  fall_counts and nofall_counts
# t = 0.80642, df = 409.33, p-value = 0.4205
# alternative hypothesis: true difference in means is not equal to 0
# 95 percent confidence interval:
#   -0.3795486  0.9075574
# sample estimates:
#   mean of x mean of y 
# 3.041322  2.777318 

unique(BPdata_ICD_year1_fall$Time_Period)
#"Daytime"   "Nighttime"
uniqueN(bp24_closest_65_clean$person_id_hashed)
#5195
bp24_closest_65_clean_dipping<-calculate_sbp_dipping(bp24_closest_65_clean)
dim(bp24_closest_65_clean_dipping)
#5195  

dim(fall_year1_dipping)
# 363   4
head(fall_year1_dipping)

#year1_dipping<-calculate_sbp_dipping(link_ICD)

round(mean(bp24_closest_65_clean_dipping$sbp_dipping, na.rm = TRUE),4)
#0.0452

round(mean(fall_year1_dipping$sbp_dipping, na.rm = TRUE),4)
#  0.0255
round(mean(nonfall_year1_dipping$sbp_dipping, na.rm = TRUE),4)
#  0.0467

summarise_sbp_groups <- function(link_data, year1_fall, year1_nofall) {
  # Create a named list of datasets
  datasets <- list(
    all = link_data,
    fall = year1_fall,
    nofall = year1_nofall
  )
  
  # Function to compute sBP summary stats
  get_sbp_summary <- function(dt) {
    data.table::data.table(
      `sBP average` = mean(dt$Systolic, na.rm = TRUE),
      `sBP SD` = sd(dt$Systolic, na.rm = TRUE),
      `Minimum sBP` = min(dt$Systolic, na.rm = TRUE),
      `sBP values <100 mm Hg` = sum(dt$Systolic < 100, na.rm = TRUE)
    )
  }
  
  # Apply summary function to each group
  summary_list <- lapply(datasets, get_sbp_summary)
  
  # Combine and round
  combined_summary <- data.table::rbindlist(summary_list, idcol = "Group")
  combined_summary <- combined_summary[, lapply(.SD, round, 3), by = Group]
  
  # Transpose and keep original row names as a column
  transposed_summary <- data.table::transpose(combined_summary, make.names = "Group")
  transposed_summary[, Variable := names(combined_summary)[-1]]
  
  # Move 'Variable' to first column
  data.table::setcolorder(transposed_summary, c("Variable", setdiff(names(transposed_summary), "Variable")))
  
  return(transposed_summary)
}

# 
# 
result_ICD <- summarise_sbp_groups(bp24_closest_65_clean, BPdata_ICD_year1_fall, BPdata_ICD_year1_nofall)
head(result_ICD)
# 
colnames(result_ICD) <- paste0(colnames(result_ICD), "_ICD")
# 
uniqueN(BPdata_ICD_year1_fall$person_id_hashed)
#363
uniqueN(BPdata_ICD_year1_fall$person_id_hashed)/uniqueN(bp24_closest_65_clean$person_id_hashed)
#0.06987488
result_ICD[4,3]
#1104
result_ICD[4,3]/363
# 3.041322
result_ICD[4,4]
#13420

result_ICD[4,4]/4832
# 2.777318
# 
# fwrite(result_ICD,
#        file = file.path("U:/Academic Unit - Bradford 24BP/CB/ABPM_trend", "ICD_fall_statistic_part1.csv")
# )
#U:\Academic Unit - Bradford 24BP\CB\3datacleaning\CB_fall_nofall
fwrite(result_ICD, "U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/ICD_fall_statistic_part1.csv")

# Generate summary stats for Daytime only
result_ICD_Daytime <- summarise_sbp_groups(
  bp24_closest_65_clean[Time_Period == "Daytime"],
  BPdata_ICD_year1_fall[Time_Period == "Daytime"],
  BPdata_ICD_year1_nofall[Time_Period == "Daytime"]
)
# Check output
head(result_ICD_Daytime)

# Rename all columns with _ICD suffix
colnames(result_ICD_Daytime) <- paste0(colnames(result_ICD_Daytime), "_ICD")
View(result_ICD_Daytime)
result_ICD_Daytime[4,3]
# 785
result_ICD_Daytime[4,3]/363
# 2.162534
result_ICD_Daytime[4,4]
# 9209
result_ICD_Daytime[4,4]/4832
# 1.905836




# Save to CSV

fwrite(result_ICD_Daytime, "U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/ICD_fall_statistic_part1Daytime.csv")



# data.table::fwrite(
#   result_ICD_Daytime,
#   file = file.path("U:/Academic Unit - Bradford 24BP/CB/ABPM_trend/", "ICD_fall_statistic_part1Daytime.csv")
# )

# Generate summary stats for Nighttime only
result_ICD_Nighttime <- summarise_sbp_groups(
  bp24_closest_65_clean[Time_Period == "Nighttime"],
  BPdata_ICD_year1_fall[Time_Period == "Nighttime"],
  BPdata_ICD_year1_nofall[Time_Period == "Nighttime"]
)

# Check output
head(result_ICD_Nighttime)

# Rename all columns with _ICD suffix
colnames(result_ICD_Nighttime) <- paste0(colnames(result_ICD_Nighttime), "_ICD")
View(result_ICD_Nighttime)
result_ICD_Nighttime[4,3]
# 319
result_ICD_Nighttime[4,3]/363
# 0.8787879
result_ICD_Nighttime[4,4]
# 4211
result_ICD_Nighttime[4,4]/4832
#  0.8714818


# Save to CSV
# data.table::fwrite(
#   result_ICD_Nighttime,
#   file = file.path("U:/Academic Unit - Bradford 24BP/CB/ABPM_trend/", "ICD_fall_statistic_part1Nighttime.csv")
# )
fwrite(result_ICD_Nighttime, "U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/ICD_fall_statistic_part1Nighttime.csv")



#5.	T test for fall, no fall on SBP-dipping
head(fall_year1_dipping)
head(nonfall_year1_dipping)
# Add a group label for each dataset
fall_year1_dipping[, group := "Fall Year 1"]
nonfall_year1_dipping[, group := "Non-Fall Year 1"]

fall_year1_dipping1 <- fall_year1_dipping[!is.na(Daytime) & !is.na(Nighttime)]
nonfall_year1_dipping1 <- nonfall_year1_dipping[!is.na(Daytime) & !is.na(Nighttime)]

dim(fall_year1_dipping1)
dim(nonfall_year1_dipping1)



t.test(
  na.omit(fall_year1_dipping1$sbp_dipping),
  na.omit(nonfall_year1_dipping1$sbp_dipping),
  alternative = "two.sided",
  var.equal = FALSE
)




# Welch Two Sample t-test
# 
# data:  na.omit(fall_year1_dipping1$sbp_dipping) and na.omit(nonfall_year1_dipping1$sbp_dipping)
# t = -4.0759, df = 378.96, p-value = 5.587e-05
# alternative hypothesis: true difference in means is not equal to 0
# 95 percent confidence interval:
#   -0.03139887 -0.01096310
# sample estimates:
#   mean of x  mean of y 
# 0.02547507 0.04665606 

##########plotting################# 

# Combine into one data.table
combined_dipping <- rbind(fall_year1_dipping[, .(sbp_dipping, group)], 
                          nonfall_year1_dipping[, .(sbp_dipping, group)])

# Calculate averages per group (excluding NA)
avg_values <- combined_dipping[, .(avg_sbp_dipping = mean(sbp_dipping, na.rm = TRUE)), by = group]
avg_values[, nudge_x := ifelse(group == "Fall Year 1", -0.015, 0.015)]





# Plot the distribution
library(ggplot2)

dev.new()
# Plot the distribution with average lines

ggplot(combined_dipping, aes(x = sbp_dipping, fill = group)) +
  geom_density(alpha = 0.5, na.rm = TRUE) +
  geom_vline(data = avg_values, aes(xintercept = avg_sbp_dipping, color = group),
             linetype = "dashed", linewidth = 1, show.legend = FALSE) +
  geom_text(data = avg_values, 
            aes(x = avg_sbp_dipping, 
                y = 5.5,  
                label = paste0(sprintf("%.1f", avg_sbp_dipping * 100), "%"),
                color = group),
            angle = 0,
            vjust = -0.5,
            hjust = ifelse(avg_values$group == "Fall Year 1", 1, 0),  # align text to left or right of x
            size = 5,
            show.legend = FALSE,
            position = position_nudge(x = avg_values$nudge_x)
  ) +
  labs(title = "Distribution of SBP Dipping (ICD health outcome)",
       x = "SBP Dipping",
       y = "Density",
       fill = "Group") +   # fix here: make it a string
  theme_bw() +
  scale_x_continuous(
    breaks = c(-0.4,-0.2, -0.1, 0, 0.1, 0.2, 0.4),
    labels = c("-40%","-20%", "-10%", "0%", "10%", "20%", "40%")
  ) +
  scale_y_continuous(
    limits = c(0,6),
    breaks = 0:6
  ) +
  theme(
    axis.title = element_text(size=14), 
    axis.text = element_text(size=12),
    strip.text.x = element_text(size=12),
    strip.text.y = element_text(size=12),
    legend.text = element_text(size=14),
    legend.title = element_text(size=14),
    axis.title.y.left = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)),
    axis.title.y.right = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10))
  )

ggsave("U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/plot/sbp_dipping_363.jpg",units="in", width=10, height=5.5, dpi=500)
fwrite(combined_dipping,"U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/fall_nofal_sbp_dipping.csv")

########################


#summary by groups
summary_stats_trend <- function(dt, group_vars) {
  dt[, .(
    avg_systolic = mean(Systolic),
    min_systolic = min(Systolic),
    max_systolic = max(Systolic),
    sd_systolic  = sd(Systolic),
    
    avg_diastolic = mean(Diastolic),
    min_diastolic = min(Diastolic),
    max_diastolic = max(Diastolic),
    sd_diastolic  = sd(Diastolic),
    
    avg_heartrate = mean(HeartRate),
    min_heartrate = min(HeartRate),
    max_heartrate = max(HeartRate),
    sd_heartrate  = sd(HeartRate),
    
    count_systolic_below_100 = sum(Systolic < 100)
  ), by = group_vars]
}

summarise_sbp_groups <- function(link_data, year1_fall, year1_nofall) {
  # Create a named list of datasets
  datasets <- list(
    all = link_data,
    fall = year1_fall,
    nofall = year1_nofall
  )
  
  # Function to compute sBP summary stats
  get_sbp_summary <- function(dt) {
    data.table::data.table(
      `sBP average` = mean(dt$Systolic, na.rm = TRUE),
      `sBP SD` = sd(dt$Systolic, na.rm = TRUE),
      `Minimum sBP` = min(dt$Systolic, na.rm = TRUE),
      `sBP values <100 mm Hg` = sum(dt$Systolic < 100, na.rm = TRUE)
    )
  }
  
  # Apply summary function to each group
  summary_list <- lapply(datasets, get_sbp_summary)
  
  # Combine and round
  combined_summary <- data.table::rbindlist(summary_list, idcol = "Group")
  combined_summary <- combined_summary[, lapply(.SD, round, 3), by = Group]
  
  # Transpose and keep original row names as a column
  transposed_summary <- data.table::transpose(combined_summary, make.names = "Group")
  transposed_summary[, Variable := names(combined_summary)[-1]]
  
  # Move 'Variable' to first column
  data.table::setcolorder(transposed_summary, c("Variable", setdiff(names(transposed_summary), "Variable")))
  
  return(transposed_summary)
}


# For 'fall' group
summary_fall_by_hour <- summary_stats_trend(BPdata_ICD_year1_fall, group_vars = "Hour")

# For 'nofall' group
summary_nofall_by_hour <- summary_stats_trend(BPdata_ICD_year1_nofall, group_vars = "Hour")

sort(unique(summary_fall_by_hour$Hour))
sort(unique(summary_nofall_by_hour$Hour))



head(BPdata_ICD_year1_nofall)

head(BPdata_ICD_year1_fall)

head(summary_fall_by_hour)

summary_fall_by_hour[, group := "Fall  Year 1"]
summary_nofall_by_hour[, group := "No Fall  Year 1"]

# Combine data
combined_summary_hour <- rbind(summary_fall_by_hour, summary_nofall_by_hour)

plot_data <- melt(combined_summary_hour, 
                  id.vars = c("Hour", "group"), 
                  measure.vars = c("avg_systolic", "avg_diastolic", "avg_heartrate"),
                  variable.name = "measure",
                  value.name = "avg_value")


# Clean up measure names for  plot labels
plot_data[, measure := factor(measure, 
                              levels = c("avg_systolic", "avg_diastolic", "avg_heartrate"),
                              labels = c("Average Systolic", "Average Diastolic", "Average Heart Rate"))]

head(plot_data)
sort(unique(plot_data$Hour))


# For hours meant to be part of the second day (e.g. repeated 0–6), add 24

plot_data_copy <- plot_data
setDT(plot_data_copy)

sort(unique(plot_data_copy$Hour))
# Add Hour_extended for original data
plot_data_copy[, Hour_extended := as.numeric(Hour)]



# Add second-day data
plot_data_add <- plot_data_copy[Hour <= 6]
plot_data_add[, Hour_extended := Hour + 24]

# Combine original and extended
plot_new <- rbind(plot_data_copy, plot_data_add)
head(plot_new)
sort(unique(plot_new$Hour_extended))

dev.new()

fwrite(plot_new,"U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/bp_hr_hour_start_plot_ICD.csv")
dev.new()
ggplot(plot_new, aes(x = as.numeric(Hour_extended), y = avg_value, color = group)) +
  geom_line(size = 0.7) +
  geom_point(size = 2)+
  facet_wrap(~measure, scales = "free_y", ncol = 1) +
  # 1. Shaded background from hour 22 to 30
  annotate("rect", xmin = 22, xmax = 30, ymin = -Inf, ymax = Inf,
           alpha = 0.2, fill = "grey30") +
  annotate("rect", xmin = 0, xmax =6, ymin = -Inf, ymax = Inf,
           alpha = 0.2, fill = "grey30") +
  # 2. Horizontal link line across hour 22 to 30 (use y = -Inf or fixed y)
  annotate("segment", x = 22, xend = 30, y = -Inf, yend = -Inf,
           colour = "black", size = 1, linetype = "solid") +
  
  # 3. Add vertical dashed lines at 6, 22, 30
  geom_vline(xintercept = c(6, 22, 30), linetype = "dashed", color = "black", size = 0.6) +
  labs(
    title = "Trend of Average Blood Pressure and Heart Rate by Hour (ICD)",
    x = "Hour of Day",
    y = "Average Value per Hour",
    color = "Group"
  ) +
  theme_bw() +
  theme(
    axis.title = element_text(size = 14), 
    axis.text = element_text(size = 12),
    strip.text.x = element_text(size = 12),
    strip.text.y = element_text(size = 12),
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 14),
    axis.title.y.left = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)),
    axis.title.y.right = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10))
  ) +
  scale_x_continuous(
    breaks = 0:30,
    labels = c(
      as.character(0:24),  # Day 1 hours
      as.character(1:6)     # Day 2 early hours (25–30 shown as 1–6)
    )
  )

ggsave("U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/plot/bp_hr_hour_ICD_new_v1_363.jpg",units="in", width=15, height=6.5, dpi=500)

dev.new()
ggplot(plot_new[Hour_extended>=6,], aes(x = as.numeric(Hour_extended), y = avg_value, color = group)) +
  geom_line(size = 0.7) +
  geom_point(size = 2)+
  facet_wrap(~measure, scales = "free_y", ncol = 1) +
  # 1. Shaded background from hour 22 to 30
  annotate("rect", xmin = 22, xmax = 30, ymin = -Inf, ymax = Inf,
           alpha = 0.2, fill = "grey30") +
  
  # 2. Horizontal link line across hour 22 to 30 (use y = -Inf or fixed y)
  annotate("segment", x = 22, xend = 30, y = -Inf, yend = -Inf,
           colour = "black", size = 1, linetype = "solid") +
  
  # 3. Add vertical dashed lines at 6, 22, 30
  geom_vline(xintercept = c(22, 30), linetype = "dashed", color = "black", size = 0.6) +
  
  
  labs(
    title = "Trend of Average Blood Pressure and Heart Rate by Hour (ICD)",
    x = "Hour of Day",
    y = "Average Value per Hour",
    color = "Group"
  ) +
  theme_bw() +
  theme(
    axis.title = element_text(size = 14), 
    axis.text = element_text(size = 12),
    strip.text.x = element_text(size = 12),
    strip.text.y = element_text(size = 12),
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 14),
    axis.title.y.left = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)),
    axis.title.y.right = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10))
  ) +
  scale_x_continuous(
    breaks = 6:30,
    labels = c(
      as.character(6:24),  # Day 1 hours
      as.character(1:6)     # Day 2 early hours (25–30 shown as 1–6)
    )
  )

ggsave("U:/Academic Unit - Bradford 24BP/CB/3datacleaning/CB_fall_nofall/plot/bp_hr_hour_ICD_new_363.jpg",units="in", width=11, height=6.5, dpi=500)

#############End 20/2/2026########################
##plot the SBP by patient####