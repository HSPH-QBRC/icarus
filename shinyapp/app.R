library(shiny)
library(ggplot2)
library(GGally)
# library(MASS)
# library(jtools)
# library(reshape2)
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

df <- loadData()

institutions <- unique(df$school)
publicSchools <- c("MA public schools", "Boston-area public schools")
universities <- institutions[! institutions %in% publicSchools]

ui <- fluidPage(
  titlePanel("ICARUS dashboard"),

  fluidRow(
    column(1, checkboxGroupInput("schools", "Schools:", universities,
                                 selected = "Harvard")),
    column(8, plotOutput("universityCasesPlot")),
    column(3, plotOutput("pairwiseCorrelations"))
  )
)

server <- function(input, output) {
  universityCasesData <- reactive(df[df$school %in% input$schools,])

  output$universityCasesPlot <- renderPlot({
    ggplot(universityCasesData(), aes(week, positive)) +
      geom_point(aes(color = school)) + geom_line(aes(color = school))
  })

  # df.uni <- df[! df$school %in% publicSchools,]
  correlationData <- reactive({
    tmp_df <- universityCasesData()[, which(
        names(universityCasesData()) %in% c(
          "county_positive", "county_density", "state_positive", "state_density",
          "metro_positive", "metro_density", "positive", "total", "week"
        )
      )]
    for (n in c(
      "county_positive", "state_positive",
      "metro_positive", "positive", "total"
    )) {
      tmp_df[, n] <- log(tmp_df[, n] + 1)
    }
    tmp_df
  })
  
  output$pairwiseCorrelations <- renderPlot({
    ggcorr(correlationData())
  })
}

shinyApp(ui, server)
