library(DBI)
library(odbc)

# sql_conn <- dbConnect(odbc::odbc(),
#                       driver = "SQL Server",
#                       server = "BHTS-CONNECTYO3",
#                       database = "CB_1745",                      
#                       Trusted_Connection = "True")
# 
# head(dbListTables(sql_conn))

sql_conn <- tryCatch({DBI::dbConnect(odbc::odbc(),driver = "ODBC Driver 17 for SQL Server", server = "bhts-connectyo3", database = "CB_1745_BP_NEW", Trusted_Connection = "Yes") }, error = function(e) {stop(sprintf("Failded to connect to SQL Server: %s", e$message))}) 

bp <- dbGetQuery(sql_conn, "SELECT * FROM dbo.tbl_bloodpressure_data_ORIGINAL")
person <- dbGetQuery(sql_conn, "SELECT person_id_hashed,year_of_birth,death_datetime,birth_datetime FROM dbo.person_ORIGINAL")
dim(person)
#19,822     4
length(unique(person$person_id_hashed))
#9911
person<-unique(person)
dim(person)
#9911
dim(bp)
#2,248,834
bp<-unique(bp)
dim(bp)
#809971     24
library(data.table)
length(unique(bp$person_id_hashed))
#9408
# Convert to data.table if not already
setDT(bp)

# Create measure_id based on unique combinations
bp[, measure_id := .GRP, by = .(tbl_bloodpressure_data_start_date, person_id_hashed)]
length(unique(bp$measure_id))
#12008

setDT(person)
gc()
#link bp and person based on person_id_hashed
bp_person<-merge(bp,person, by="person_id_hashed")
dim(bp)
#  809,971  
length(unique(bp_person$person_id_hashed))
#9408


length(unique(person$person_id_hashed))-length(unique(bp_person$person_id_hashed))
#503
bp_person[, birth_date := as.Date(birth_datetime)]
head(bp_person)
#for each measure id
bp_person[, bp24_start_date := as.Date(tbl_bloodpressure_data_start_date)]
length(unique(bp_person$measure_id))
####
####Dividing by 365.25
#Converts the number of days into years. We use 365.25 days/year (instead of 365) to roughly account for leap years (every 4 years adds an extra day).
# Step 1: Compute age in years at bp24_start_date
bp_person[, age_at_bp24 := as.numeric(difftime(bp24_start_date, birth_date, units = "days")) / 365.25]
dim(bp_person)
#809971     30
length(unique(bp_person$person_id_hashed))
#9408
# Step 2: Filter records where age >= 65
bp_over_65 <- bp_person[age_at_bp24 >=65]
dim(bp_over_65)
# 437663     30
length(unique(bp_over_65$person_id_hashed))
#5197
length(unique(bp_over_65$measure_id))
#6511
bp_over_65<-unique(bp_over_65)
dim(bp_over_65)
#437663 
DBI::dbWriteTable(sql_conn, 
                  name = DBI::Id(schema = "dbo", table = "bp_over_65"), 
                  value = bp_over_65, 
                  overwrite = TRUE)  
#######################################################################################################
#####Validate the patients in Jose's health outcome data who are not in the BP over age 65 data.#######
########################################################################################################
# unmatched_id_in_healthICD <- dbGetQuery(sql_conn, "SELECT * FROM dbo.CB_unmatched_id_in_healthICD")
# unmatched_id_in_bp65_ICD <- dbGetQuery(sql_conn, "SELECT * FROM dbo.CB_unmatched_id_in_bp65_ICD") 
# uniqueN(unmatched_id_in_healthICD$person_id_hashed)
# Extract the ABMP records for the patients who no longer exist in BP65 but are present in HealthOutcome.
#c1<-bp_person[bp_person$person_id_hashed %in% unmatched_id_in_healthICD$person_id_hashed, c("person_id_hashed","birth_date","age_at_bp24","bp24_start_date") ]
#c1<-unique(c1)
# uniqueN(c1$person_id_hashed)
# 
# setequal(unmatched_id_in_healthICD$person_id_hashed, c1$person_id_hashed)
# #
# sort(unique(c1$age_at_bp24))
# # 64.60233 64.60780 64.61602 64.61875 64.64613 64.65435 64.66804 64.67351 64.67625 64.68172 64.70089 64.70910 64.72005 64.72553 64.76386
# #64.80219 64.80493 64.81314 64.82683 64.83504 64.84326 64.84600 64.85421 64.86790 64.88159 64.88433 64.89802 64.90349 64.90623 64.94182
# # #64.94730 64.95551 64.96372 64.96920 64.97194 64.97741 64.98289 64.98563 64.98836 64.99658 79.60575 86.57358
# # # All the missing BP records were measurements taken before age 65
# DBI::dbWriteTable(sql_conn,
#                   name = DBI::Id(schema = "dbo", table = "BP_list_unmatched_in_healthoutcome"),
#                   value = c1,
#                   overwrite = TRUE)
# 
# # rm(c1)



# Extract the ABMP records for the patients who exist in BP65 but are not present in the HealthOutcome data
# c2<-bp_person[bp_person$person_id_hashed %in% unmatched_id_in_bp65_ICD$person_id_hashed, c("person_id_hashed","birth_date","age_at_bp24","bp24_start_date") ]
# c2<-unique(c2)
# uniqueN(c2$person_id_hashed)
# #75
# setequal(unmatched_id_in_bp65_ICD$person_id_hashed, c2$person_id_hashed)
# #I can find these patients in the raw ABPM
# sort(unique(c2$age_at_bp24))

#These missing patients do exist in the raw BP data, with at least one ABPM taken after age 65
# 46.65845 47.65777 50.05613 50.34908 51.09103 51.09377 52.00548 52.61328 53.47296 53.77139 54.27242 54.85284 55.19233 55.98084 56.18344
#56.30664 56.42710 56.58590 56.82409 56.86242 57.20739 57.48939 57.58795 57.69473 58.06434 58.56537 58.61739 58.66667 58.67762 58.80903
#58.84736 58.89117 58.89938 58.90486 58.92676 59.03628 59.12663 59.18686 59.41136 59.44695 59.54552 59.63313 59.69610 59.89049 59.98357
#59.98631 60.15058 60.24093 60.32854 60.38056 60.43806 60.46543 60.55031 60.62971 60.64339 60.74743 60.76660 60.79124 60.99932 61.56879
# 61.63997 61.64545 61.64819 61.69473 61.70568 61.83162 61.89185 62.03696 62.04517 62.07255 62.12731 62.17933 62.24504 62.26146 62.40657
# 62.44764 62.47502 62.48049 62.49966 62.81999 62.88296 63.12389 63.18138 63.24983 63.30732 63.35113 63.37029 63.40041 63.47159 63.50445
#63.52361 63.59754 63.74812 63.78919 63.81109 63.86037 63.92608 64.00821 64.05476 64.07118 64.16153 64.16975 64.19165 64.23546 64.26557
#64.29569 64.32033 64.32854 64.51198 64.61602 64.70089 64.70910 64.80493 64.86790 64.87611 64.92539 65.01848 65.04038 65.04312 65.05681
# 65.08966 65.11704 65.13621 65.14168 65.16085 65.17454 65.24298 65.25394 65.32238 65.39357 65.44285 65.45380 65.64271 65.68104 65.72485
#65.75496 65.82615 65.87543 65.88090 65.88638 65.91102 65.91650 65.97947 66.01232 66.04517 66.13279 66.25325 66.26420 66.34634 66.39288
# 66.40657 66.43669 66.58453 66.59548 66.64203 66.65298 66.65845 66.75702 66.78713 66.79535 66.81177 66.81451 66.86653 66.92129 67.00068
# 67.10746 67.12389 67.24709 67.44422 67.47707 67.57016 67.71526 67.83299 67.87406 67.90418 67.91239 67.94798 67.97810 68.00274 68.02190
#68.05476 68.06297 68.21355 68.22724 68.25188 68.25462 68.50650 68.64613 68.75291 68.77481 68.81040 69.08145 69.10062 69.11157 69.19097
# 69.19370 69.65640 69.73306 69.74949 69.84257 70.22861 70.25599 70.63655 70.72690 70.88843 70.91307 71.15400 71.33196 71.57016 71.76181
#71.84394 72.30938 72.83504 72.88433 72.91992 73.00205 73.24025 73.35797 74.17933 74.20397 74.54894 74.90760 75.49076 75.65503 75.72895
# #76.65982 80.95825
# head(c2)
# c2[c2$person_id_hashed=="00D836D66A3ADF9F18C4F703FD1F074AAF364CFA60082BA372536502EC34C36A", ]
# 
# # person_id_hashed birth_date age_at_bp24 bp24_start_date
# # <char>     <Date>       <num>          <Date>
# #   1: 00D836D66A3ADF9F18C4F703FD1F074AAF364CFA60082BA372536502EC34C36A 1959-04-15    63.24983      2022-07-15
# # 2: 00D836D66A3ADF9F18C4F703FD1F074AAF364CFA60082BA372536502EC34C36A 1959-04-15    62.24504      2021-07-13
# # 3: 00D836D66A3ADF9F18C4F703FD1F074AAF364CFA60082BA372536502EC34C36A 1959-04-15    65.04038      2024-04-29
# # 4: 00D836D66A3ADF9F18C4F703FD1F074AAF364CFA60082BA372536502EC34C36A 1959-04-15    59.98631      2019-04-10
# # 5: 00D836D66A3ADF9F18C4F703FD1F074AAF364CFA60082BA372536502EC34C36A 1959-04-15    59.41136      2018-09-12
# # 6: 00D836D66A3ADF9F18C4F703FD1F074AAF364CFA60082BA372536502EC34C36A 1959-04-15    64.86790      2024-02-26
# 
# c2[c2$person_id_hashed=="F83156E29E4A5EC9A123B8B3DB4B0232D78F6386537BBEB7BDF95BB332225F06", ]
# 
# #   person_id_hashed birth_date age_at_bp24 bp24_start_date
# # <char>     <Date>       <num>          <Date>
# #   1: F83156E29E4A5EC9A123B8B3DB4B0232D78F6386537BBEB7BDF95BB332225F06 1956-07-15    67.94798      2024-06-26
# # 2: F83156E29E4A5EC9A123B8B3DB4B0232D78F6386537BBEB7BDF95BB332225F06 1956-07-15    65.68104      2022-03-21
# # 3: F83156E29E4A5EC9A123B8B3DB4B0232D78F6386537BBEB7BDF95BB332225F06 1956-07-15    62.88296      2019-06-03
# # 4: F83156E29E4A5EC9A123B8B3DB4B0232D78F6386537BBEB7BDF95BB332225F06 1956-07-15    64.32854      2020-11-12
# 
# DBI::dbWriteTable(sql_conn, 
#                   name = DBI::Id(schema = "dbo", table = "BP65_list_not_in_healthoutcome"), 
#                   value = c2, 
#                  overwrite = TRUE) 

#######################################################################################################
###################################### End of Validation ##############################################
########################################################################################################
length(unique(bp_over_65$person_id_hashed))
#
# For each person_id_hashed, select the row with age_at_bp24 closest to 65
bp_closest_65 <- bp_over_65[
  , .SD[which.min(abs(age_at_bp24 - 65))],
  by = person_id_hashed
]

# Check number of unique persons (should equal number of rows)
length(unique(bp_closest_65$person_id_hashed))
# 5197

# Filter the original data to only those measure_ids selected above
bp24_closest_65 <- bp_over_65[measure_id %in% bp_closest_65$measure_id]
dim(bp24_closest_65)
#348034     30
# Check again unique persons in this filtered set
length(unique(bp24_closest_65$person_id_hashed))
# 5197

bp24_closest_65<-unique(bp24_closest_65)
dim(bp24_closest_65)
#348034     30

# Write the filtered data frame to the database table dbo.bp24_closest_65
DBI::dbWriteTable(
  conn = sql_conn, 
  name = DBI::Id(schema = "dbo", table = "bp24_closest_65"), 
  value = bp24_closest_65, 
  overwrite = TRUE
)

# bB <- dbGetQuery(sql_conn, "SELECT * FROM dbo.bp24_closest_65")
# rm(bB)


#-------------------Retire all the following the move to 2_2---------------------------------------
##############################################################
#####conduct the statistic based on bp24_closest_65#######
##############################################################
head(bp24_closest_65)

#in bp24_closest_65, count the unique measure_id for  each person_id_hashed  


# Count unique measure_id per person_id_hashed
unique_measure_counts <- bp24_closest_65[, .(unique_measure_count = uniqueN(measure_id)), by = person_id_hashed]

# View the result
head(unique_measure_counts)
unique(unique_measure_counts$unique_measure_count)
#1
rm(unique_measure_counts)

####Count how many records for each person_id_hashed
# Count records per person
person_record_counts <- bp24_closest_65[, .N, by = person_id_hashed]
setnames(person_record_counts, "N", "record_count")

# View a few results
head(person_record_counts)
#rm(unique_measure_counts)

### Calculate measurement duration for each person using time_day, time_hour, and time_minutes
#install.packages("lubridate")  # run this if you haven't installed it yet
library(lubridate)  

library(data.table)

# Make sure bp24_closest_65 is a data.table
setDT(bp24_closest_65)

# Create measurement_datetime by adding days, hours, and minutes (in seconds) to bp24_start_date
bp24_closest_65[, measurement_datetime := as.POSIXct(bp24_start_date) + 
                  as.numeric(Time_Day) * 86400 +
                  as.numeric(Time_Hour) * 3600 +
                  as.numeric(Time_Minute) * 60]



# Calculate min and max measurement time per person_id_hashed
duration_per_person <- bp24_closest_65[, .(
  start_time = min(measurement_datetime, na.rm = TRUE),
  end_time = max(measurement_datetime, na.rm = TRUE)
), by = person_id_hashed]

# Calculate measurement duration in minutes, hours, and days
duration_per_person[, duration_minutes := as.numeric(difftime(end_time, start_time, units = "mins"))]
duration_per_person[, duration_hours := duration_minutes / 60]
duration_per_person[, duration_days := duration_minutes / 1440]

# View the result
head(duration_per_person)

dim(person_record_counts)
dim(duration_per_person)

merged_statistic <- merge( person_record_counts,duration_per_person, by = "person_id_hashed", all = TRUE)

# View result
head(merged_statistic)

##then 

unique(bp24_closest_65$ErrorStatus)


# Replace NA in ErrorStatus with "noerror"
bp24_closest_65[, ErrorStatus := fifelse(is.na(ErrorStatus), "noerror", ErrorStatus)]

# Calculate counts of each ErrorStatus per person
error_counts_person <- bp24_closest_65[, .N, by = .(person_id_hashed, ErrorStatus)]

# Calculate total counts per person
error_counts_person[, total := sum(N), by = person_id_hashed]

# Calculate error rate per ErrorStatus per person
error_counts_person[, rate := N / total]

# View result
print(error_counts_person)

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
merged_errors <- merge(error_rates_wide, error_counts_wide, by = "person_id_hashed", all = TRUE)

# Merge merged_errors with merged_statistic by person_id_hashed (full outer join)
bp24_statistic_by_person <- merge(merged_errors, merged_statistic, by = "person_id_hashed", all = TRUE)

# Save the merged data.table to CSV file

bp24_closest_65_id<-bp24_closest_65[,c("bp24_start_date","age_at_bp24","year_of_birth","person_id_hashed")]

bp24_closest_65_id<-unique(bp24_closest_65_id)
bp24_statistic_by_person_all<-merge(bp24_statistic_by_person,bp24_closest_65_id, by = "person_id_hashed")
fwrite(bp24_statistic_by_person_all, "H:/data/24BP-Falls/bp24_statistic_by_person.csv")

####summaries
# Turn off scientific notation globally
options(scipen = 999)

# Now show the summary without scientific notation
summary(bp24_statistic_by_person_all)

isss<-bp24_statistic_by_person_all[bp24_statistic_by_person_all$duration_hours >25,]
dim(isss)[1]/dim(bp24_statistic_by_person_all)[1]
dim(bp24_statistic_by_person_all[bp24_statistic_by_person_all$RecorderIndicatedError ==bp24_statistic_by_person_all$record_count,])[1]
#
dim(bp24_statistic_by_person_all[bp24_statistic_by_person_all$RecorderIndicatedError ==bp24_statistic_by_person_all$record_count,])[1]/dim(bp24_statistic_by_person_all)[1]
library(data.table)
c1<-bp24_statistic_by_person_all[bp24_statistic_by_person_all$RecorderIndicatedError ==bp24_statistic_by_person_all$record_count,]
# Convert to data.table if not already
dt <- as.data.table(bp24_statistic_by_person_all)



summarize_col <- function(col) {
  if (is.numeric(col)) {
    return(list(
      Min = min(col, na.rm=TRUE),
      Q1 = quantile(col, 0.25, na.rm=TRUE),
      Median = median(col, na.rm=TRUE),
      Mean = mean(col, na.rm=TRUE),
      Q3 = quantile(col, 0.75, na.rm=TRUE),
      Max = max(col, na.rm=TRUE)
    ))
  } else if (inherits(col, "Date")) {
    q_num <- quantile(as.numeric(col), probs = c(0.25, 0.5, 0.75), na.rm=TRUE)
    return(list(
      Min = as.character(min(col, na.rm=TRUE)),
      Q1 = as.character(as.Date(q_num[1], origin="1970-01-01")),
      Median = as.character(as.Date(q_num[2], origin="1970-01-01")),
      Mean = NA,
      Q3 = as.character(as.Date(q_num[3], origin="1970-01-01")),
      Max = as.character(max(col, na.rm=TRUE))
    ))
  } else if (inherits(col, "POSIXct")) {
    q <- quantile(col, probs=c(0.25, 0.5, 0.75), na.rm=TRUE)
    return(list(
      Min = as.character(min(col, na.rm=TRUE)),
      Q1 = as.character(q[1]),
      Median = as.character(q[2]),
      Mean = NA,
      Q3 = as.character(q[3]),
      Max = as.character(max(col, na.rm=TRUE))
    ))
  } else if (inherits(col, "integer64")) {
    col_num <- as.numeric(col)
    return(list(
      Min = min(col_num, na.rm=TRUE),
      Q1 = quantile(col_num, 0.25, na.rm=TRUE),
      Median = median(col_num, na.rm=TRUE),
      Mean = mean(col_num, na.rm=TRUE),
      Q3 = quantile(col_num, 0.75, na.rm=TRUE),
      Max = max(col_num, na.rm=TRUE)
    ))
  } else {
    # For non-numeric/non-date columns return NA
    return(list(
      Min = NA,
      Q1 = NA,
      Median = NA,
      Mean = NA,
      Q3 = NA,
      Max = NA
    ))
  }
}

# Apply to all columns except first
summary_list <- lapply(dt[, -1, with=FALSE], summarize_col)

summary_dt <- rbindlist(lapply(names(summary_list), function(nm) {
  c(Column = nm, summary_list[[nm]])
}), fill=TRUE)

head(summary_dt)




fwrite(summary_dt, "H:/data/24BP-Falls/bp24_statistic_summary_min_q1_median_mean_q3_max.csv")

###create two separate plots—one for noerror_rate and one for duration_hours

library(ggplot2)

dev.new()

ggplot(bp24_statistic_by_person_all, aes(x = noerror_rate)) +
  geom_histogram(binwidth = 0.02, fill = "steelblue", alpha = 0.7) +
  labs(title = "Distribution of No Error Rate", x = "No Error Rate", y = "Count") +
  theme_bw()+
  theme(axis.title = element_text(size=14), axis.text = element_text(size=12),strip.text.x = element_text(size=12),strip.text.y = element_text(size=12),legend.text = element_text(size=14),legend.title = element_text(size=14),axis.title.y.left = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)),axis.title.y.right = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)))



ggsave("H:/data/24BP-Falls/Figure_no_error_rate.jpg",
       units = "in", width = 10, height = 5.5, dpi = 500)

ggplot(bp24_statistic_by_person_all, aes(x = duration_hours)) +
  geom_histogram(binwidth = 1, fill = "forestgreen", alpha = 0.7) +
  labs(title = "Distribution of Duration (Hours)", x = "Duration (hours)", y = "Count")  +
  theme_bw()+
  geom_vline(xintercept = 24, color = "black", linetype = "dashed", size = 0.5) +
  theme(axis.title = element_text(size=14), axis.text = element_text(size=12),strip.text.x = element_text(size=12),strip.text.y = element_text(size=12),legend.text = element_text(size=14),legend.title = element_text(size=14),axis.title.y.left = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)),axis.title.y.right = element_text(margin = margin(t = 0, r = 10, b = 0, l = 10)))


ggsave("H:/data/24BP-Falls/Figure_duration_hours.jpg",units="in", width=12, height=5.5, dpi=500)

##further cleaning

#only keep ErrorStatus is null(noerror)
unique(bp24_closest_65$ErrorStatus)
#

