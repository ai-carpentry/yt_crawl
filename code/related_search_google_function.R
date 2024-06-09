library(httr)
library(rvest)
library(stringr)
library(dplyr)
library(tibble)
library(purrr)
library(tidyr)
library(tidygraph)
library(ggraph)
library(showtext)

font_add_google("Noto Sans KR", "notosanskr")
showtext_auto()

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

get_related_google_search <- function(search_name) {
  
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

# 2. 데이터 전처리 -----------------------------------

convert_from_wide_to_nw <- function(rawdata) {
  
  lvl_one_tbl <- rawdata %>%
    select(from = keyword, to = lvl_01) %>%
    distinct(.)
  
  lvl_two_tbl <- rawdata %>%
    select(from = lvl_01, to = lvl_02)
  
  nw_tbl <- bind_rows(lvl_one_tbl, lvl_two_tbl)
  
  nw_tbl
}

# 그래프 생성 및 저장 함수
create_google_graph <- function(search_term) {
  # 연관 검색어 데이터 가져오기
  graph_raw <- get_related_search(search_term)
  
  # 데이터 전처리
  graph_tbl <- convert_from_wide_to_nw(graph_raw)
  
  # 그래프 생성
  graph_gg <- graph_tbl %>% 
    as_tbl_graph(directed=FALSE) %>%
    activate(nodes) %>%
    mutate(eigen = centrality_eigen(),
           group = group_infomap()) %>%
    ggraph(layout='nicely') +
    geom_edge_link(color='gray50', alpha=.2) +
    geom_node_point(aes(color=factor(group), size=eigen)) +
    geom_node_text(aes(label=name), size = 10, repel=TRUE) +
    theme_minimal(base_family = "notosanskr") +
    theme_graph(base_family = "notosanskr") +
    theme(legend.position = "none",
          plot.title = element_text(size = 50, face="bold")) +
    labs(title = str_glue("{search_term} : 구글 검색 연관검색어"))
  
  return(graph_gg)
}

# 그래프 생성 및 저장 함수
create_and_save_google_graph <- function(search_term) {
  # 연관 검색어 데이터 가져오기
  graph_raw <- get_related_search(search_term)
  
  # 데이터 전처리
  graph_tbl <- convert_from_wide_to_nw(graph_raw)
  
  # 그래프 생성
  graph_gg <- graph_tbl %>% 
    as_tbl_graph(directed=FALSE) %>%
    activate(nodes) %>%
    mutate(eigen = centrality_eigen(),
           group = group_infomap()) %>%
    ggraph(layout='nicely') +
    geom_edge_link(color='gray50', alpha=.2) +
    geom_node_point(aes(color=factor(group), size=eigen)) +
    geom_node_text(aes(label=name), size = 10, repel=TRUE) +
    theme_minimal(base_family = "notosanskr") +
    theme_graph(base_family = "notosanskr") +
    theme(legend.position = "none",
          plot.title = element_text(size = 50, face="bold")) +
    labs(title = str_glue("{search_term} : 구글 검색 연관검색어"))
  
  # 그래프 저장
  output_file <- str_glue("images/{search_term}_구글연관검색어.jpeg")
  
  ragg::agg_jpeg(output_file, width = 10, height = 7, units = "in", res = 300)
  print(graph_gg)
  dev.off()
  
  fs::file_copy(output_file, str_glue("images/{str_remove_all(Sys.Date(), '-')}_{search_term}_구글.jpeg"), overwrite = TRUE)
  
  cat(str_glue("그래프가 {output_file}에 저장되었습니다.\n"))
}

# # 그래프 생성 및 저장
# search_term <- c("윤석열", "민주당", "이재명", "국민의힘", "조국")
# 
# create_and_save_graph(search_term[3])
# 
# walk(search_term, create_and_save_graph)
# 
# 
# create_and_save_graph("김건희")
