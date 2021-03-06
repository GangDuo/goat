#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(shiny)
library(dplyr)
library(DT)

db.driver <- dbDriver("MySQL")
db.connector <- dbConnect(db.driver,
                          dbname=config::get("dbname2"),
                          user=config::get("user2"), password=config::get("password2"),
                          host=config::get("host"), port=config::get("port")) 
dbGetQuery(db.connector, "SET NAMES utf8")
weeklyShelfSales <- dbGetQuery(db.connector, config::get('qWeeklyShelfSales'))
dbDisconnect(db.connector)

# Define server logic required to draw a histogram
shinyServer(function(input, output, session) {

  fetchLocation <- function(){
    db.driver <- dbDriver("MySQL")
    db.connector <- dbConnect(db.driver,
                              dbname=config::get("dbname"),
                              user=config::get("user"), password=config::get("password"),
                              host=config::get("host"), port=config::get("port")) 
    dbGetQuery(db.connector, "SET NAMES utf8")
    location <- dbGetQuery(db.connector, config::get('qlocation'))
    dbDisconnect(db.connector)
    return(location)
  }
  
  filterCategoryAsVector = reactive({
    as.vector(lapply(input$category, function(i) {
      as.numeric(unlist(strsplit(i, " "))[1])
    }), mode = "list")
  })
  
  filterDivisionAsVector = reactive({
    location <- fetchLocation()
    # ccategoryとdivisionが未選択
    if(length(input$category) == 0 && length(input$division) == 0){
      return(location[!is.na(location$parent) & location$parent >= 100, c('display_name')])
    }
    
    if(length(input$category) == 0){
      # divisionのみ選択
      codes <- as.vector(unlist(lapply(input$division, function(j) {
        as.numeric(paste0(unlist(strsplit(j, " "))[1]))
      })), mode = "list")
    } else {
      codes <- as.vector(lapply(input$category, function(i) {
        pcode <- as.numeric(unlist(strsplit(i, " "))[1])
        
        # divisionが未選択の場合
        if(length(input$division) == 0){
          seq(as.numeric(paste0(pcode, '00')), as.numeric(paste0(pcode, '99')), 1)
        } else {
          unlist(lapply(input$division, function(j) {
            as.numeric(paste0(unlist(strsplit(j, " "))[1]))
          }))
        }
      }), mode = "list")
    }
    # flatten
    codes <- do.call(c, codes)
    family <- location[!is.na(location$parent) & location$parent %in% codes, c('display_name')]
  })
  
  observe({
    if(is.null(input$category))return()
    
    location<-fetchLocation()
    division <- location[!is.na(location$parent) & location$parent %in% filterCategoryAsVector(), c('display_name')]
    updateSelectInput(session, "division", choices = division)
  })
  
  observe({
    updateSelectInput(session, "family", choices = filterDivisionAsVector())
  })
  
  #------------------------------------------------------
  # 最上部グラフ
  # 単位：千円
  #------------------------------------------------------
  filterWithUserData <- function(arg) {
    data.result <- arg %>%
      dplyr::filter(Year == input$year + 2000)
    
    # もっとましなのが思いつかない
    if(length(input$family) > 0){
      codes <- as.vector(unlist(lapply(input$family, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 1, 2)))
      })), mode = "list")
      data.result <- data.result %>%
        dplyr::filter(Category %in% codes)
      
      codes <- as.vector(unlist(lapply(input$family, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 3, 4)))
      })), mode = "list")
      data.result <- data.result %>%
        dplyr::filter(Division %in% codes)
      
      codes <- as.vector(unlist(lapply(input$family, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 5, 6)))
      })), mode = "list")
      data.result <- data.result %>%
        dplyr::filter(Family %in% codes)
    } else if(length(input$division) > 0){
      codes <- as.vector(unlist(lapply(input$division, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 3, 4)))
      })), mode = "list")
      data.result <- data.result %>%
        dplyr::filter(Category %in% codes)
      
      codes <- as.vector(unlist(lapply(input$division, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 5, 6)))
      })), mode = "list")
      data.result <- data.result %>%
        dplyr::filter(Division %in% codes)
    } else if(length(input$category) > 0){
      codes <- as.vector(lapply(input$category, function(i) {
        pcode <- as.numeric(unlist(strsplit(i, " "))[1])
      }), mode = "list")
      data.result <- data.result %>%
        dplyr::filter(Category %in% codes)
    } 
    return(data.result)
  }

  filterWeeklySalesTrends = reactive({
    data.result <- weeklyShelfSales %>% filterWithUserData
    
    data.result <- data.result %>%
      dplyr::group_by(WeekOfYear) %>%
      dplyr::summarise(f1=sum(SalesAmountOfPreviousYear)/1000, f2=sum(SalesAmount)/1000) %>%
      dplyr::select(f1,f2)
    
    source <- t(data.result)
    colnames(source) <- 1:ncol(source)
    rownames(source) <- c("前年", "本年")
    
    return(source)
  })
  
  output$plot_weekly_sales_trends <- renderPlot({
    source <- filterWeeklySalesTrends()
    barplot(source,
            beside = TRUE,
            col = c("grey", "red"),
            legend = rownames(source),
            args.legend = list(x="topright",
                               bty="n"    # 枠消去
            ),
            las=1) # y軸の目盛を90°回転
  })

  #------------------------------------------------------
  # グラフのデータソース
  #------------------------------------------------------
  filterWeeklySalesTrendsForTbl = reactive({
    source <- weeklyShelfSales %>%
      filterWithUserData %>%
      dplyr::group_by(WeekOfYear, FirstDayOfWeek) %>%
      dplyr::summarise(f1=sum(SalesAmountOfPreviousYear)/1000
                       , f2=sum(SalesAmount)/1000) %>%
      dplyr::select(WeekOfYear, FirstDayOfWeek, f1, f2) %>%
      dplyr::mutate(FirstDayOfWeek = format(as.Date(FirstDayOfWeek), "%Y-%m-%d"))
    colnames(source) <- c("週", "週の開始日", "前年[千円]", "本年[千円]")
    return(source)
  })
  
  output$tbl_weekly_sales_trends = DT::renderDataTable({
    datatable(
      filterWeeklySalesTrendsForTbl(),
      selection = list(mode = "single"),
      options = list(searching = FALSE,
                     ordering = FALSE,
                     language = list(url = '//cdn.datatables.net/plug-ins/9dcbecd42ad/i18n/Japanese.json')
      )
    ) %>%
      formatCurrency(columns = c("前年[千円]", "本年[千円]"), currency = "",
                     interval = 3, mark = ",", digits = 0) 
  })
  
  #------------------------------------------------------
  # ランキング
  #------------------------------------------------------
  buildTitle = reactive({
    prefix <- ""
    
    year <- input$year
    if (!is.null(year)) {
      prefix <- paste(prefix, year, "年")
    }
    
    i <- input$tbl_weekly_sales_trends_rows_selected
    if (!is.null(i)) {
      prefix <- paste(prefix, i, "週")
    }
    return(prefix)
  })
  output$tab_title_topn <- renderText({
    paste(buildTitle(), "Top20")
  })
  output$tab_title_bottomn <-renderText({
    paste(buildTitle(), "Bottom20")
  })
  
  buildWhere = reactive({
    where <- sprintf("WHERE Year = %1$d", input$year + 2000)
    if(!is.null(input$tbl_weekly_sales_trends_rows_selected)){
      where <- paste(where, sprintf("AND WeekOfYear = %1$d", input$tbl_weekly_sales_trends_rows_selected))
    }
    if(length(input$family) > 0){
      codes <- as.vector(unlist(lapply(input$family, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 1, 2)))
      })), mode = "list")
      codes <- unique(codes)
      where <- paste(where, 'AND Category IN(', paste(codes, collapse = ','), ')')
      
      codes <- as.vector(unlist(lapply(input$family, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 3, 4)))
      })), mode = "list")
      codes <- unique(codes)
      where <- paste(where, 'AND Division IN(', paste(codes, collapse = ','), ')')
      
      codes <- as.vector(unlist(lapply(input$family, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 5, 6)))
      })), mode = "list")
      codes <- unique(codes)
      where <- paste(where, 'AND Family IN(', paste(codes, collapse = ','), ')')
    } else if(length(input$division) > 0){
      codes <- as.vector(unlist(lapply(input$division, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 3, 4)))
      })), mode = "list")
      codes <- unique(codes)
      where <- paste(where, 'AND Category IN(', paste(codes, collapse = ','), ')')
      
      codes <- as.vector(unlist(lapply(input$division, function(j) {
        as.numeric(paste0(substring(unlist(strsplit(j, " "))[1], 5, 6)))
      })), mode = "list")
      codes <- unique(codes)
      where <- paste(where, 'AND Division IN(', paste(codes, collapse = ','), ')')
    } else if(length(input$category) > 0){
      codes <- as.vector(lapply(input$category, function(i) {
        pcode <- as.numeric(unlist(strsplit(i, " "))[1])
      }), mode = "list")
      codes <- unique(codes)
      where <- paste(where, 'AND Category IN(', paste(codes, collapse = ','), ')')
    } 
    return(where)
  })
  ranking <- function(order) {
    db.driver <- dbDriver("MySQL")
    db.connector <- dbConnect(db.driver,
                              dbname=config::get("dbname2"),
                              user=config::get("user2"), password=config::get("password2"),
                              host=config::get("host"), port=config::get("port")) 
    dbGetQuery(db.connector, "SET NAMES utf8")
    result <- dbGetQuery(db.connector,
                         sprintf(
                           "SELECT ModelNumber,
                           TProducts.name,
                           SUM(SalesAmountOfPreviousYear),
                           SUM(SalesAmount)
                           FROM `emother`.`WeeklyShelfSalesLines`
                           LEFT JOIN `humpty_dumpty`.`TProducts`
                           ON `TProducts`.`jan` = `WeeklyShelfSalesLines`.`ModelNumber`
                           %1$s
                           GROUP BY `ModelNumber`, ProductName
                           ORDER BY SUM(SalesAmount) %2$s,
                           SUM(SalesAmountOfPreviousYear) %2$s
                           LIMIT 20",
                           buildWhere(),
                           order)
    )
    source <- result #%>% filterWithUserData
    dbDisconnect(db.connector)  
    return(source)
  }
  
  renderRankingTable <- function(source){
    colnames(source) <- c("品番", "品名", "前年", "本年")
    
    datatable(
      source,
      #style = 'bootstrap',
      escape = FALSE,# 画像のimgタグ有効にする
      selection = list(mode = "single"),
      options = list(searching = FALSE,
                     ordering = FALSE,
                     language = list(url = '//cdn.datatables.net/plug-ins/9dcbecd42ad/i18n/Japanese.json')
      )
    ) %>%
      formatCurrency(columns = c("前年", "本年"), currency = "",
                     interval = 3, mark = ",", digits = 0) 
  }
  
  output$tbl_topn <-DT::renderDataTable({
    source <- ranking('DESC') %>%
      renderRankingTable
  })
  output$tbl_bottomn <-DT::renderDataTable({
    source <- ranking("ASC") %>%
      renderRankingTable
  })

})
