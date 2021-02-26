library(shiny)
library(ggplot2)
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

ui <- fluidPage(
    
    titlePanel("ICARUS dashboard"),

    fluidRow(
        column(6,
               h3(textOutput("universityCasesCaption")),
               plotOutput("universityCasesPlot")
        ),
        column(6,
               h3(textOutput("countyCasesCaption")),
               plotOutput("countyCasesPlot")
        ),
    ),
)

server <- function(input, output) {
    output$universityCasesCaption <- renderText("University positive cases")
    output$universityCasesPlot <- renderPlot({
        ggplot(df, aes(week, positive)) + geom_point(aes(color = school)) + facet_wrap("school")
    })
    output$countyCasesCaption <- renderText("Matched county positive cases")
    output$countyCasesPlot <- renderPlot({
        ggplot(df, aes(week, county)) + geom_point(aes(color = school)) + facet_wrap("school")
    })
}

shinyApp(ui, server)
