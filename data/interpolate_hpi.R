nat = subset(read.table("http://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_PO_us_and_census.txt", header = TRUE), division == "USA")
nat$id = 0
nat$type = "National"
nat = nat[, c("id", "division", "year", "qtr", "index_po_not_seasonally_adjusted", "type")]

states = read.table("http://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_PO_state.txt", header = TRUE, sep = "\t")
states$id = as.numeric(factor(states$state))
states$type = "State"
states = states[, c("id", "state", "yr", "qtr", "index_nsa", "type")]

po = read.table("http://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_PO_metro.txt", header = TRUE)
po$type = "MSA Purchase Only"
po = po[, c("cbsa", "metro_name", "yr", "qtr", "index_nsa", "type")]

ref = read.table("http://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_AT_metro.txt", header = FALSE, sep = "\t")
names(ref) = c("metro_name", "cbsa", "yr", "qtr", "index_nsa", "change")
ref$type = "MSA Purchase and Refi"
ref = ref[, c("cbsa", "metro_name", "yr", "qtr", "index_nsa", "type")]
ref$index_nsa = as.character(ref$index_nsa)
ref$index_nsa[ref$index_nsa == "-"] = NA
ref$index_nsa = as.numeric(ref$index_nsa)
ref = ref[!is.na(ref$index_nsa), ]
ref = ref[!(ref$cbsa %in% unique(po$cbsa)), ]

names_vector = c("id", "name", "yr", "qtr", "index_nsa", "type")
names(nat) = names_vector
names(states) = names_vector
names(po) = names_vector
names(ref) = names_vector

hpi = rbind(nat, states, po, ref)

hpi$loghpi = log(hpi$index_nsa)
hpi$month = hpi$qtr * 3

ids = sort(unique(hpi$id))

interpolate_hpi = function(hpi_id) {
  df = subset(hpi, id == hpi_id)
  
  df$xval = df$yr * 12 + df$month - 1
  
  interp = approx(x = df$xval, y = df$loghpi, xout = min(df$xval):max(df$xval))
  
  output = data.frame(
    id = as.numeric(df$id[1]),
    name = as.character(df$name[1]),
    year = interp$x %/% 12,
    month = interp$x %% 12 + 1,
    hpi = exp(interp$y),
    type = as.character(df$type[1]),
    stringsAsFactors = FALSE
  )
  
  return(output)
}

processed_hpi = do.call("rbind", lapply(ids, function(x) interpolate_hpi(x)))
processed_hpi$date = as.Date(paste(processed_hpi$year, processed_hpi$month, "01", sep="-"))

interpolated_hpi_values = processed_hpi[, c("id", "date", "hpi")]

hpi_index_codes = processed_hpi[!duplicated(processed_hpi[, c("id", "name", "type")]), c("id", "name", "type", "date")]

write.table(interpolated_hpi_values, file = "interpolated_hpi_values.txt", sep="|", row.names = FALSE, col.names = FALSE, quote = FALSE)
write.table(hpi_index_codes, file = "hpi_index_codes.txt", sep="|", row.names = FALSE, col.names = FALSE, quote = FALSE)
