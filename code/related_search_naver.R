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

# library(RSelenium)

# 1. 네이버 연관 검색 크롤링 -----------------------------------

# devtools::install_github("johndharrison/binman")
# devtools::install_github("johndharrison/wdman")
# devtools::install_github("ropensci/RSelenium")

system("taskkill /im java.exe /f", intern=FALSE, ignore.stdout=FALSE)

# 1. 데이터 ----
rem_driver <- rsDriver(browser="firefox")
remdrv_client <- rem_driver[["client"]]

naver_query <- glue::glue("https://search.naver.com/search.naver?ie=UTF-8&sm=whl_hty&query=김건희")

remdrv_client$navigate(naver_query)

search_box_element <- remdrv_client$findElement("css selector", "#nx_query")
search_box_element$clickElement()

keywords_list <- remdrv_client$findElement("css selector", ".kwd_lst._kwd_list")

keywords <- keywords_list$getElementText() %>% unlist()

keywords

remdrv_client$close()



# 2. chromote ----------------------------------------------------------------

# Load necessary packages
library(chromote)
library(tidyverse)

# Create a new Chromote session
b <- ChromoteSession$new()

# Navigate to the Naver search page
b$Page$navigate("https://www.naver.com/")

# Wait for the page to load
Sys.sleep(3)

# Enter the search term in the search box
b$Input$insertText(text = "김건희")
b$Input$dispatchKeyEvent(type = "keyDown", key = "Enter")
b$Input$dispatchKeyEvent(type = "keyUp", key = "Enter")

# Wait for the search results to load
Sys.sleep(1)

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

# Retrieve the array object properties
properties <- b$Runtime$getProperties(objectId = result$result$objectId)

# Extract and print the keywords
keywords <- map(properties$result, ~ .x$value$value) |> unlist()

print(keywords[1:10])

# Close the Chromote session
b$close()

# 3. 함수 -------------------------------------------------------------------

library(tidyverse)
library(chromote)

# Function to get related search terms from Naver
get_naver_term <- function(term = "윤석열") {
  tryCatch({
    # Create a new Chromote session
    b <- ChromoteSession$new()
    
    # Navigate to the Naver search page
    b$Page$navigate("https://www.naver.com/")
    b$Page$loadEventFired(wait_ = TRUE)
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
    message("Error occurred: ", e)
    return(NULL)
  })
}

search_term <- "윤석열"

lvl_01 <- get_naver_term(search_term)


naver_search_raw <- lvl_01 |> 
  enframe() |> 
  mutate(keyword = search_term) |>
  select(keyword, lvl_01 = value) |> 
  mutate(lvl_01 = str_remove(lvl_01, keyword) |> str_trim()) |> 
  filter(lvl_01 != "") 


# 4. 연관 검색어 시각화 --------------------------------------------

# 그래프 생성
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
  
# 그래프 저장
output_file <- str_glue("images/{search_term}_네이버연관검색어.jpeg")

ragg::agg_jpeg(output_file, width = 10, height = 7, units = "in", res = 300)
print(naver_graph_gg)
dev.off()
  


