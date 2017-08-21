#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(shiny)
library(config)
library(DBI)
library(RMySQL)
library(DT)

db.driver <- dbDriver("MySQL")
db.connector <- dbConnect(db.driver,
                          dbname=config::get("dbname"),
                          user=config::get("user"), password=config::get("password"),
                          host=config::get("host"), port=config::get("port")) 
#dbGetQuery(db.connector, "SET NAMES cp932") # if windows
dbGetQuery(db.connector, "SET NAMES utf8")

stores <- dbGetQuery(db.connector, config::get("qstores"))
categories <- dbGetQuery(db.connector, config::get("qcategories"))
division <- dbGetQuery(db.connector, config::get("qdivision"))
family <- dbGetQuery(db.connector, config::get("qfamily"))

dbDisconnect(db.connector)

# Define UI for application that draws a histogram
shinyUI(fluidPage(
  
  headerPanel("年間週別売上金額推移"),
  
  verticalLayout(
    # 週間売上推移
    plotOutput("plot_weekly_sales_trends", height = "300px"),

    sidebarLayout(
      position = "left",
      sidebarPanel(
        selectInput("category", "カテゴリ", categories, NULL, TRUE),
        selectInput("division", "小分類", division, NULL, TRUE),
        selectInput("family", "棚名", family, NULL, TRUE),
        selectInput("store", "店舗:", stores, NULL, TRUE),
        sliderInput("year", "年:", 15, 20, 17)
      ),
      
      mainPanel(
        splitLayout(
          tabsetPanel(
            tabPanel("週間売上金額推移", DT::dataTableOutput("tbl_weekly_sales_trends")),
            tabPanel(textOutput("tab_title_top20"), DT::dataTableOutput("tbl_top20")),
            tabPanel(textOutput("tab_title_bottom20"), DT::dataTableOutput("tbl_bottom20")),
            tabPanel("選択行", DT::dataTableOutput('selected'))
          )
        )
      )
    )
  )
  
))
