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
  db.driver <- dbDriver("MySQL")
  db.connector <- dbConnect(db.driver,
                            dbname=config::get("dbname2"),
                            user=config::get("user2"), password=config::get("password2"),
                            host=config::get("host"), port=config::get("port")) 
  dbGetQuery(db.connector, "SET NAMES utf8")
  weeklyShelfSales <- dbGetQuery(db.connector, config::get('qWeeklyShelfSales'))
  dbDisconnect(db.connector)


  filterWeeklySalesTrends = reactive({
    data.result <- weeklyShelfSales %>%
      dplyr::filter(Year == input$year + 2000)
    
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
})
