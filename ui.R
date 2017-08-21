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

db.driver <- dbDriver("MySQL")
db.connector <- dbConnect(db.driver,
                          dbname=config::get("dbname"),
                          user=config::get("user"), password=config::get("password"),
                          host=config::get("host"), port=config::get("port")) 
#dbGetQuery(db.connector, "SET NAMES cp932") # if windows
dbGetQuery(db.connector, "SET NAMES utf8")

dbDisconnect(db.connector)

# Define UI for application that draws a histogram
shinyUI(fluidPage(
  


))
