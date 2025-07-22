#This is the code to conduct linkage between dbo.tbl_bloodpressure_data and dbo.person
# Bin Chi
#22/7/2025

library(DBI)
library(odbc)
library(data.table)

sql_conn <- tryCatch({DBI::dbConnect(odbc::odbc(),driver = "ODBC Driver 17 for SQL Server", server = "bhts-connectyo3", database = "CB_1745", Trusted_Connection = "Yes") }, error = function(e) {stop(sprintf("Failded to connect to SQL Server: %s", e$message))}) 
#Load the data
bp <- dbGetQuery(sql_conn, "SELECT * FROM dbo.tbl_bloodpressure_data")
person <- dbGetQuery(sql_conn, "SELECT person_id_hashed,year_of_birth,death_datetime,birth_datetime FROM dbo.person")

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
#809971     23

setDT(person)
gc()

#link bp and person based on person_id_hashed
bp_person<-merge(bp,person, by="person_id_hashed")
dim(bp)
#  809,971  
length(unique(bp_person$person_id_hashed))
#9408

head(bp_person)
bp_person[, birth_date := as.Date(birth_datetime)]
head(bp_person)
#for each measure id
bp_person[, bp24_start_date := as.Date(tbl_bloodpressure_data_start_date)]
#Dividing by 365.25
#Converts the number of days into years. We use 365.25 days/year (instead of 365) to roughly account for leap years (every 4 years adds an extra day).
# Compute age in years at bp24_start_date
bp_person[, age_at_bp24 := as.numeric(difftime(bp24_start_date, birth_date, units = "days")) / 365.25]
dim(bp_person)
#809971     30
length(unique(bp_person$person_id_hashed))
#9408

# Create measurement_datetime by adding days, hours, and minutes (in seconds) to bp24_start_date
bp_person[, measurement_datetime := as.POSIXct(bp24_start_date) + 
            as.numeric(Time_Day) * 86400 +
            as.numeric(Time_Hour) * 3600 +
            as.numeric(Time_Minute) * 60]


test<-bp_person[,.(measurement_datetime,Time_Day,Time_Hour,Time_Minute,bp24_start_date,tbl_bloodpressure_data_start_date,person_id_hashed)]

setorder(test, person_id_hashed,Time_Day,Time_Hour,Time_Minute)

rm(test)
gc()
# Calculate min and max measurement time per person_id_hashed
duration_per_person <- bp_person[, .(
  start_time = min(measurement_datetime, na.rm = TRUE),
  end_time = max(measurement_datetime, na.rm = TRUE)
), by = person_id_hashed]

# Calculate measurement duration in minutes, hours, and days
duration_per_person[, duration_minutes := as.numeric(difftime(end_time, start_time, units = "mins"))]
duration_per_person[, duration_hours := duration_minutes / 60]
duration_per_person[, duration_days := duration_minutes / 1440]

bp24_patient <- merge(bp_person,duration_per_person, by = "person_id_hashed", all = TRUE)

dim(bp_person)
#809971     30
length(unique(bp_person$person_id_hashed))
#9408

dim(bp24_patient)
#809971     36
length(unique(bp24_patient$person_id_hashed))
#9408


DBI::dbWriteTable(sql_conn, 
                  name = DBI::Id(schema = "dbo", table = "bp24_patient"), 
                  value = bp24_patient, 
                  overwrite = TRUE)  
