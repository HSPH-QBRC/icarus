library(shiny)
library(ggplot2)
library(GGally)
library(mongolite)

options(mongodb = list(
    "host" = Sys.getenv("MONGODB_HOSTNAME"),
    "username" = Sys.getenv("MONGODB_USERNAME"),
    "password" = Sys.getenv("MONGODB_PASSWORD")
))
databaseName <- "covid"
collectionName <- "isoweeks"

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
  return(data)
}

df <- loadData()

institutions <- unique(df$school)
publicSchools <- c("MA public schools", "Boston-area public schools")
universities <- institutions[! institutions %in% publicSchools]

# convert ISO weeks to the dates of Monday of each ISO week
df$week <- as.Date(paste0(df$week, "1"), format = "%Y%W%u")

# ui <- fluidPage(
# titlePanel("ICARUS dashboard"),
ui <- navbarPage(
  "ICARUS dashboard",
  tabPanel(
    "Schools",
    fluidRow(
      column(12, plotOutput("universityCasesPlot")),
    ),
    fluidRow(
      column(1, checkboxGroupInput("schools", "Schools:", institutions,
                                    selected = "Harvard")),
      column(8, tableOutput("correlationCoefficients")),
      column(3, plotOutput("pairwiseCorrelations")),
    ),
    markdown("
    Case Density: the number of cases per 100k population calculated using a 7-day rolling average.
    ")
  ),
  tabPanel(
    "Areas",
    fluidRow(
      column(12, plotOutput("universityAreaCasesPlot")),
    ),
    fluidRow(
      column(6, radioButtons("school", "Schools:", universities,
                             selected = "Harvard", inline = TRUE)),
      column(6, radioButtons("area", "Surrounding areas:",
                             c("Metro" = "metro_positive",
                               "County" = "county_positive",
                               "State" = "state_positive"), inline = TRUE)),
    ),
  ),
  tabPanel(
    "Miscellaneous",
    markdown("
      Additional resources:
      * [Radiant app](https://ivyplus.shinyapps.io/radiant)
      * [Analysis report](https://ivyplus.shinyapps.io/icarus-report)
      
      Data sources:
      * University COVID-19 dashboards
      * [Massachusetts Department of Elementary and Secondary Education (DESE)](https://www.doe.mass.edu/covid19/positive-cases/)
      * [CovidActNow Data API](https://covidactnow.org/data-api)
    ")
  )
)

server <- function(input, output) {
  universityCasesData <- reactive(df[df$school %in% input$schools,])

  output$universityCasesPlot <- renderPlot({
    ggplot(universityCasesData(), aes(week, positive)) +
      geom_point(aes(color = school)) + geom_line(aes(color = school))
  })

  correlationData <- reactive({
    tmp_df <- universityCasesData()[, which(
        names(universityCasesData()) %in% c(
          "county_positive", "county_density", "state_positive", "state_density",
          "metro_positive", "metro_density", "positive", "total", "week"
        )
      )]
    for (n in c(
      "county_positive", "state_positive", "metro_positive", "positive", "total"
    )) {
      tmp_df[, n] <- log(tmp_df[, n] + 1)
    }
    return(tmp_df[,-1])
  })

  output$pairwiseCorrelations <- renderPlot(ggcorr(correlationData()))

  output$correlationCoefficients <- renderTable(cor(correlationData()),
                                                rownames = TRUE)

  output$universityAreaCasesPlot <- renderPlot({
    ggplot(df[df$school %in% input$school,], aes(week, !!sym(input$area))) +
      geom_line()
  })

}

shinyApp(ui, server)
