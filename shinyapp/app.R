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
    sidebarLayout(
      sidebarPanel(
        checkboxGroupInput("schools", "Schools:", institutions,
                           selected = "Harvard"),
        width = 3
      ),
      mainPanel(
        tabsetPanel(
          tabPanel("Cases", plotOutput("universityCasesPlot")),
          tabPanel(
            "Correlations",
            tableOutput("correlationCoefficients"),
            plotOutput("pairwiseCorrelations"),
            markdown("
              Case Density: the number of cases per 100k population calculated using a 7-day rolling average.
            "),
          )
        ),
        width = 9
      )
    ),
  ),
  tabPanel(
    "Areas",
    sidebarLayout(
      sidebarPanel(
        radioButtons("school", "Schools:", universities, selected = "Harvard"),
        radioButtons("area", "Surrounding areas:",
                     c("Metro" = "metro_positive",
                       "County" = "county_positive",
                       "State" = "state_positive")),
        width = 3
      ),
      mainPanel(
        plotOutput("universityAreaCasesPlot"),
        width = 9
      )
    )
  ),
  tabPanel(
    "Other",
    markdown("
      Additional resources:
      * [Radiant app](https://ivyplus.shinyapps.io/radiant): a powerful GUI statistical analysis tool for the ICARUS data
      * [Analysis report](https://ivyplus.shinyapps.io/icarus-report): an example pilot analysis of the analysis capabilities provided by the ICARUS data platform
      
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
  }, res = 96)

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

  output$pairwiseCorrelations <- renderPlot(ggcorr(correlationData()), res = 96)

  output$correlationCoefficients <- renderTable(cor(correlationData()),
                                                rownames = TRUE)

  output$universityAreaCasesPlot <- renderPlot({
    ggplot(df[df$school %in% input$school,], aes(week, !!sym(input$area))) +
      geom_line()
  }, res = 96)

}

shinyApp(ui, server)
