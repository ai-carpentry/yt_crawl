library(tidyverse)
library(arrow)
library(fs)

channels_parquet <- fs::dir_ls("data/channel/", glob = "*.parquet")

channels_stat <- channels_parquet %>% 
  enframe() |> 
  select(value) |> 
  mutate(data = map(value, open_dataset)) |> 
  mutate(data = map(data, collect)) |> 
  unnest(cols = c(data)) |> 
  janitor::clean_names() |> 
  mutate(channel =  str_extract(value, "UC[A-Za-z0-9_-]+(?=_\\d{8}_channel_info)")) |> 
  relocate(channel, .before = value) |> 
  select(-value)

channels_stat %>%
  write_feather("data/channel_stat.feather")

