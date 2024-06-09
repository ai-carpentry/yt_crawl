library(httr)
library(rvest)
library(stringr)
library(dplyr)
library(tibble)
library(purrr)
library(tidyr)

# 1. 구글 연관 검색 크롤링 -----------------------------------

get_search <- function(keyword = "이재명") {
  
  query <- stringr::str_glue("https://suggestqueries.google.com/complete/search?output=toolbar&q={keyword}")
  url_query <- URLencode(query)
  
  resp <- content(GET(url_query))
  
  ### 데이터프레임 변환
  resp %>%
    html_elements('suggestion') %>%
    html_attr("data")
}


get_related_search <- function(search_name) {
  
  keyword_raw <- tibble(keyword = search_name)
  
  keyword_tbl <- keyword_raw %>%
    mutate(lvl_01 = map(keyword, get_search)) %>%
    unnest(lvl_01) %>%
    mutate(lvl_02 = map(lvl_01, get_search)) %>%
    unnest(lvl_02)
  
  keyword_tbl <- keyword_tbl %>%
    mutate(dup_check = case_when(keyword == lvl_01 ~ TRUE,
                                 lvl_01 == lvl_02 ~ TRUE,
                                 TRUE ~ FALSE)) %>%
    filter(!dup_check) %>%
    select(-dup_check) |> 
    ## 중복 제거
    mutate(lvl_02 = str_remove(lvl_02, lvl_01) |> str_trim(),
           lvl_01 = str_remove(lvl_01, keyword) |> str_trim()) 
  
  return(keyword_tbl)
}

google_keyword <- "민주당"

sample_tbl <- get_related_search(google_keyword)

# 2. 데이터 전처리 -----------------------------------

library(tidygraph)
library(ggraph)
library(showtext)  # Load the showtext package

font_add_google("Noto Sans KR", "notosanskr")  # Add Noto Sans Korean font
showtext_auto()  # Enable showtext

convert_from_wide_to_nw <- function(rawdata) {
  
  lvl_one_tbl <- rawdata %>%
    select(from = keyword, to = lvl_01) %>%
    distinct(.)
  
  lvl_two_tbl <- rawdata %>%
    select(from = lvl_01, to = lvl_02)
  
  nw_tbl <- bind_rows(lvl_one_tbl, lvl_two_tbl)
  
  nw_tbl
}

sample_graph_tbl <- convert_from_wide_to_nw(sample_tbl)

# 3. 데이터 시각화 -----------------------------------

sample_graph_g <- sample_graph_tbl %>% 
  as_tbl_graph(directed=FALSE) %>%
  activate(nodes) %>%
  mutate(eigen = centrality_eigen(),
         group = group_infomap()) %>%
  ggraph(layout='nicely') +
  geom_edge_link(color='gray50', alpha=.2) +
  geom_node_point(aes(color=factor(group), size=eigen)) +
  geom_node_text(aes(label=name), size = 20, repel=TRUE) +
  theme_minimal(base_family = "notosanskr") +
  theme_graph(base_family = "notosanskr") +
  theme(legend.position = "none",
        plot.title = element_text(size = 100, face="bold")) +
  labs(title = str_glue("{google_keyword} : 구글 검색 연관검색어"))

ragg::agg_jpeg(str_glue("images/{google_keyword}_구글연관검색어.jpeg"), width = 10, height = 7, units = "in", res = 600)
sample_graph_g
dev.off()


