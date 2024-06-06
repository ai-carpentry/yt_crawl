library(arrow)
library(fs)
library(dplyr)
library(janitor)
library(tidyr)
library(tibble)

channels_parquet <- fs::dir_ls("data/", glob = "*channel_info.parquet")

channels_stat <- channels_parquet %>% 
  enframe() |> 
  select(value) |> 
  mutate(data = map(value, open_dataset)) |> 
  mutate(data = map(data, collect)) |> 
  unnest(cols = c(data)) |> 
  clean_names() |> 
  mutate(channel =  str_extract(value, "UC[A-Za-z0-9_-]+(?=_\\d{8}_channel_info)")) |> 
  relocate(channel, .before = value) |> 
  select(-value)

channels_stat %>%
  write_feather("data/channel_stat.feather")

