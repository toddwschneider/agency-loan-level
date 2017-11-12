library(tidyverse)

nat = read_delim("https://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_PO_us_and_census.txt", delim = "\t") %>%
  filter(division == "USA") %>%
  mutate(id = 0, type = "National") %>%
  select(id, division, year, qtr, index_po_not_seasonally_adjusted, type)

states = read_delim("https://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_PO_state.txt", delim = "\t") %>%
  mutate(id = as.numeric(factor(state)), type = "State") %>%
  select(id, state, yr, qtr, index_nsa, type)

po = read_delim("https://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_PO_metro.txt", delim = "\t") %>%
  mutate(type = "MSA Purchase Only") %>%
  select(cbsa, metro_name, yr, qtr, index_nsa, type)

ref = read_delim("http://www.fhfa.gov/DataTools/Downloads/Documents/HPI/HPI_AT_metro.txt",
                 delim = "\t",
                 na = "-",
                 col_names = c("metro_name", "cbsa", "yr", "qtr", "index_nsa", "change")) %>%
  mutate(type = "MSA Purchase and Refi") %>%
  filter(!is.na(index_nsa), !(cbsa %in% unique(po$cbsa))) %>%
  select(cbsa, metro_name, yr,  qtr, index_nsa, type)

names_vector = c("id", "name", "yr", "qtr", "index_nsa", "type")
names(nat) = names_vector
names(states) = names_vector
names(po) = names_vector
names(ref) = names_vector

hpi = bind_rows(nat, states, po, ref) %>%
  mutate(
    loghpi = log(index_nsa),
    month = qtr * 3
  )

ids = sort(unique(hpi$id))

interpolate_hpi = function(hpi_id) {
  df = filter(hpi, id == hpi_id) %>%
    mutate(xval = yr * 12 + month - 1)

  interp = approx(x = df$xval, y = df$loghpi, xout = min(df$xval):max(df$xval))

  data_frame(
    id = hpi_id,
    name = df$name[1],
    year = interp$x %/% 12,
    month = interp$x %% 12 + 1,
    hpi = exp(interp$y),
    type = df$type[1]
  )
}

processed_hpi = map(ids, interpolate_hpi) %>%
  bind_rows() %>%
  mutate(date = as.Date(paste(year, month, "01", sep = "-")))

interpolated_hpi_values = processed_hpi %>%
  select(id, date, hpi)

hpi_index_codes = processed_hpi %>%
  group_by(id, name, type) %>%
  summarize(date = min(date)) %>%
  ungroup()

write_delim(interpolated_hpi_values, path = "interpolated_hpi_values.txt", delim = "|", col_names = FALSE)
write_delim(hpi_index_codes, path = "hpi_index_codes.txt", delim = "|", col_names = FALSE)
