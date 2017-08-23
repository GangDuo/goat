#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(shiny)

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
  
})
