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
          tabPanel(
            "Cases",
            plotOutput("universityCasesPlot"),
            markdown(
              "The data was normalized to [ISO week](https://en.wikipedia.org/wiki/ISO_week_date) (starts on Monday). Daily data was aggregated over the time period to become weekly. We defined the Boston area public schools as the districts of:
* Arlington
* Boston
* Brookline
* Cambridge
* Chelsea
* Everett
* Malden
* Medford
* Newton
* Quincy
* Somerville
* Watertown"
            )
          ),
          tabPanel(
            "Correlations",
            tableOutput("correlationCoefficients"),
            plotOutput("pairwiseCorrelations"),
            markdown(
              "Case Density: the number of cases per 100k population calculated using a 7-day rolling average. Local area data has been split by county, state, and metro area."
            ),
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
        radioButtons(
          "area", 
          "Surrounding areas:",
          c(
            "Metro" = "metro_positive",
            "County" = "county_positive",
            "State" = "state_positive"
          ),
        ),
        sliderInput(
          "datesrange",
          "Dates:",
          min = min(df$week[!is.na(df$week)]),
          max = max(df$week[!is.na(df$week)]),
          value = c(
            min(df$week[!is.na(df$week)]),
            max(df$week[!is.na(df$week)])
          ),
          dragRange = T
        ),
        width = 3
      ),
      mainPanel(
        plotOutput("universityAreaCasesPlot"),
        markdown(
          "The following relates the school with their corresponding local area:
* Boston College
	* county: Middlesex
	* state: MA
	* metro: Boston-Cambridge-Newton, MA-NH
* Columbia
	* county: New York
	* state: NY
	* metro: New York-Newark-Jersey City, NY-NJ-PA
* Dartmouth
	* county: Grafton
	* state: NH
	* metro: Lebanon, NH-VT
* Harvard
	* county: Middlesex
	* state: MA
	* metro: Boston-Cambridge-Newton, MA-NH
* Northeastern
	* county: Suffolk
	* state: MA
	* metro: Boston-Cambridge-Newton, MA-NH
* Princeton
	* county: Mercer
	* state: NJ
	* metro: Trenton, NJ"
        ),
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

  output$universityAreaCasesPlot <- renderPlot(
    { 
      df.flt <- df[df$school %in% input$school & df$week >= input$datesrange[1] & df$week <= input$datesrange[2], ]
      ggplot(
        rbind(
          data.frame(
            week = df.flt$week,
            value = df.flt$positive,
            fct = rep("school", length(df.flt$week))
          ),
          data.frame(
            week = df.flt$week,
            value = df.flt[, toString(sym(input$area))],
            fct = rep("area", length(df.flt$week))
          )
        )
      ) + geom_line(
        aes(week, value, color = fct)
      ) + facet_wrap(~fct, scales = "free", ncol = 1) + theme(legend.position="none")
    },
    res = 96
  )

}

shinyApp(ui, server)
