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

ui <- fluidPage(
  titlePanel("ICARUS dashboard"),

  fluidRow(
    column(1, checkboxGroupInput("schools", "Schools:", institutions,
                                 selected = "Harvard")),
    column(8, plotOutput("universityCasesPlot")),
    column(3, plotOutput("pairwiseCorrelations"))
  ),

  fluidRow(
    column(2, radioButtons("school", "Schools:", universities,
                           selected = "Harvard")),
    column(8, plotOutput("universityAreaCasesPlot")),
    column(2, radioButtons("area", "Surrounding areas:",
                           c("Metro" = "metro_positive",
                             "County" = "county_positive",
                             "State" = "state_positive"))),
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
      "county_positive", "state_positive", "metro_positive", "positive", "total"
    )) {
      tmp_df[, n] <- log(tmp_df[, n] + 1)
    }
    return(tmp_df)
  })

  output$pairwiseCorrelations <- renderPlot({
    ggcorr(correlationData())
  })

  output$universityAreaCasesPlot <- renderPlot({
    ggplot(df[df$school %in% input$school,], aes(week, !!sym(input$area))) +
      geom_line()
  })

}

shinyApp(ui, server)
