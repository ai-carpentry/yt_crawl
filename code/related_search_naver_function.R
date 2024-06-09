library(httr)
library(rvest)
library(stringr)
library(dplyr)
library(tibble)
library(purrr)
library(tidyr)
library(chromote)
library(tidygraph)
library(ggraph)
library(showtext)

font_add_google("Noto Sans KR", "notosanskr")
showtext_auto()

# Function to get related search terms from Naver
get_naver_term <- function(term = "윤석열", max_retries = 3) {
  attempt <- 1
  while (attempt <= max_retries) {
    tryCatch({
      # Create a new Chromote session
      b <- ChromoteSession$new()
      
      # Navigate to the Naver search page
      b$Page$navigate("https://www.naver.com/")
      b$Page$loadEventFired(wait_ = TRUE, timeout = 60000)
      Sys.sleep(2)  # Increased sleep time to ensure page is loaded
      
      # Focus on the search box and enter the search term
      b$Input$insertText(text = term)
      b$Input$dispatchKeyEvent(type = "keyDown", key = "Enter")
      b$Input$dispatchKeyEvent(type = "keyUp", key = "Enter")
      Sys.sleep(3)  # Increased sleep time to ensure search results are loaded
      
      # JavaScript code to extract related search keywords
      js_code <- '
      function extractKeywords() {
          const keywordsElements = document.querySelectorAll(".kwd_lst._kwd_list .kwd_txt");
          const keywords = Array.from(keywordsElements).map(element => element.textContent.trim());
          return keywords;
      }
      extractKeywords();
      '
      
      # Execute the JavaScript code and get the results
      result <- b$Runtime$evaluate(js_code)
      
      if (is.null(result$result$objectId)) {
        stop("Failed to get objectId from evaluation result")
      }
      
      # Retrieve the array object properties
      properties <- b$Runtime$getProperties(objectId = result$result$objectId)
      
      # Extract and print the keywords
      keywords <- map(properties$result, ~ .x$value$value) |> unlist()
      
      # Close the Chromote session
      b$close()
      
      return(keywords[1:10])
    }, error = function(e) {
      if (attempt == max_retries) {
        message("Error occurred: ", e)
        return(NULL)
      } else {
        attempt <<- attempt + 1
        message("Retry attempt: ", attempt)
      }
    })
  }
}

# Function to create and save the graph
create_naver_graph <- function(search_term) {
  # Get the related search terms
  lvl_01 <- get_naver_term(search_term)
  
  if (is.null(lvl_01)) {
    cat(str_glue("Failed to retrieve data for {search_term}\n"))
    return(NULL)
  }
  
  # Process the raw search terms
  naver_search_raw <- lvl_01 |> 
    enframe() |> 
    mutate(keyword = search_term) |>
    select(keyword, lvl_01 = value) |> 
    mutate(lvl_01 = str_remove(lvl_01, keyword) |> str_trim()) |> 
    filter(lvl_01 != "") 
  
  # Create the graph
  naver_graph_gg <- naver_search_raw %>% 
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
    labs(title = str_glue("{search_term} : 네이버 검색 연관검색어"))
  
  return(naver_graph_gg)
}


# Function to create and save the graph
create_and_save_naver_graph <- function(search_term) {
  # Get the related search terms
  lvl_01 <- get_naver_term(search_term)
  
  if (is.null(lvl_01)) {
    cat(str_glue("Failed to retrieve data for {search_term}\n"))
    return(NULL)
  }
  
  # Process the raw search terms
  naver_search_raw <- lvl_01 |> 
    enframe() |> 
    mutate(keyword = search_term) |>
    select(keyword, lvl_01 = value) |> 
    mutate(lvl_01 = str_remove(lvl_01, keyword) |> str_trim()) |> 
    filter(lvl_01 != "") 
  
  # Create the graph
  naver_graph_gg <- naver_search_raw %>% 
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
          plot.title = element_text(size = 70, face="bold")) +
    labs(title = str_glue("{search_term} : 네이버 검색 연관검색어"))
  
  # Save the graph
  output_file <- str_glue("images/{search_term}_네이버연관검색어.jpeg")
  
  ragg::agg_jpeg(output_file, width = 10, height = 7, units = "in", res = 300)
  print(naver_graph_gg)
  dev.off()

  fs::file_copy(output_file, str_glue("images/{str_remove_all(Sys.Date(), '-')}_{search_term}_네이버.jpeg"), overwrite = TRUE)
    
  cat(str_glue("그래프가 {output_file}에 저장되었습니다.\n"))
}

# # 그래프 생성 및 저장
# search_terms <- c("윤석열", "민주당", "이재명", "국민의힘", "조국", "김건희")
# 
# walk(search_terms, create_and_save_graph)
# 
# create_and_save_graph("김건희")
# create_and_save_graph("김정숙")
# create_and_save_graph("김혜경")


# 2. 네트워크 데이터셋 ------------------------------------------------------------

get_nw_data <- function(search_term = "김건희") {
  
  lvl_01 <- get_naver_term(search_term)
  
  # Process the raw search terms
  naver_search_raw <- lvl_01 |> 
    enframe() |> 
    mutate(keyword = search_term) |>
    select(keyword, lvl_01 = value) |> 
    mutate(lvl_01 = str_remove(lvl_01, keyword) |> str_trim()) |> 
    filter(lvl_01 != "") 
  
  return(naver_search_raw)
}

get_related_naver_data <- function(search_term = "김건희") {
  
  lvl_01 <- get_naver_term(search_term)
  
  # Process the raw search terms
  naver_search_raw <- lvl_01 |> 
    enframe() |> 
    mutate(keyword = search_term) |>
    select(keyword, lvl_01 = value) |> 
    mutate(lvl_01 = str_remove(lvl_01, keyword) |> str_trim()) |> 
    filter(lvl_01 != "") 
  
  return(naver_search_raw)
}

# kkh_tbl <- get_nw_data("김건희")
# 
# kkh_tbl |> 
#   clipr::write_clip()
# 
# 
# kjs_tbl <- get_nw_data("김정숙")
# 
# kjs_tbl |> 
#   clipr::write_clip()
# 
# 
# khk_tbl <- get_nw_data("김혜경")
# 
# khk_tbl |> 
#   clipr::write_clip()

