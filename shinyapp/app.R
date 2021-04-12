library(shiny)
library(ggplot2)
library(GGally)
library(MASS)
library(jtools)
library(reshape2)
library(mongolite)

options(mongodb = list(
    "host" = Sys.getenv("MONGODB_HOSTNAME"),
    "username" = Sys.getenv("MONGODB_USERNAME"),
    "password" = Sys.getenv("MONGODB_PASSWORD")
))
databaseName <- "covid"
collectionName <- "allTestingData"

loadData <- function() {
  # Connect to the database
  db <- mongo(
    collection = collectionName,
    url = sprintf(
      "mongodb+srv://%s:%s@%s/%s?retryWrites=true&w=majority",
      options()$mongodb$username,
      options()$mongodb$password,
      options()$mongodb$host,
      databaseName
    )
  )
  # Read all the entries
  data <- db$find()
  data
}

ui <- fluidPage(
  titlePanel("ICARUS dashboard"),

  selectInput("school", "School:", c("BC",
                                     "Columbia",
                                     "Dartmouth",
                                     "Harvard",
                                     "Northeastern",
                                     "Princeton")),
  plotOutput("universityCasesPlot"),
)

server <- function(input, output) {
  df <- loadData()
  schoolData <- reactive(df[df$school %in% c(input$school),])

  output$universityCasesPlot <- renderPlot({
    ggplot(schoolData(), aes(week, positive)) + geom_point()
  })

}

shinyApp(ui, server)
