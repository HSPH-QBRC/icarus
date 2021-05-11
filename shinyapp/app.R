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
            "Metro" = "metro",
            "County" = "county",
            "State" = "state"
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
        tabsetPanel(
          tabPanel(
            "Cases",
            plotOutput("universityAreaCasesPlot"),
            markdown("### Cross correlation
The cross correlation identifies time lag of the university's positive test 
counts and the chosen area metric - based on weekly data. For example, a peak 
at 0 indicates that there is no time lag between the university and area
testing data. The blue hashed lines indicate the 95% confidence interval for 
background noise."),
            plotOutput("universityAreaCasesCCFPlot")
          ),
          tabPanel(
            "Vaccinations",
            plotOutput("universityAreaVaccinesPlot"),
            markdown("### Cross correlation
The cross correlation identifies time lag of the university's positive test 
counts and the chosen area vaccine metric - based on weekly data. For example, a peak 
at 0 indicates that there is no time lag between the university testing results and area
vaccination data. The blue hashed lines indicate the 95% confidence interval for 
background noise."),
            plotOutput("universityAreaVaccinesCCFPlot")
          )
        ),
        markdown(
          "### Data providence
The following relates the school with their corresponding local area:
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
    "Correlations",
    sidebarLayout(
      sidebarPanel(
        checkboxGroupInput(
          "schoolsscat",
          "Schools:",
          institutions,
          select = "Harvard"
        ),
        selectInput(
          "xgroup",
          "X axis",
          colnames(df)[! colnames(df) %in% c("school", "week")]
        ),
        selectInput(
          "ygroup",
          "Y axis",
          colnames(df)[! colnames(df) %in% c("school", "week")]
        ),
        sliderInput(
          "datesrangescat",
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
        plotOutput("xycomparison"),
        plotOutput("xyscatterplot"),
        htmlOutput("xycorrelation")
      )
    )
  ),
  tabPanel(
    "Query Table",
    sidebarLayout(
      sidebarPanel(
        checkboxGroupInput(
          "schoolsquery",
          "Schools:",
          institutions,
          select = "Harvard"
        ),
        checkboxGroupInput(
          "featurequery",
          "Features:",
          colnames(df),
          select = c("school", "positive")
        ),
        sliderInput(
          "datesrangequery",
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
        dataTableOutput("queryTable")
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
      dfFilteredSchoolDate <- df[df$school %in% input$school & df$week >= input$datesrange[1] & df$week <= input$datesrange[2], ]
      casesArea <- switch(
        input$area,
        metro = "metro_positive",
        county = "county_positive",
        state = "state_positive",
        "metro_positive"
      )

      ggplot(
        rbind(
          data.frame(
            week = dfFilteredSchoolDate$week,
            value = dfFilteredSchoolDate$positive,
            fct = rep("school", length(dfFilteredSchoolDate$week))
          ),
          data.frame(
            week = dfFilteredSchoolDate$week,
            value = dfFilteredSchoolDate[, casesArea],
            fct = rep("area", length(dfFilteredSchoolDate$week))
          )
        )
      ) + geom_line(
        aes(week, value, color = fct)
      ) + facet_wrap(~fct, scales = "free", ncol = 1) + theme(legend.position="none")
    },
    res = 96
  )

  output$universityAreaCasesCCFPlot <- renderPlot(
    {
      # should probably make this reactive.
      dfCasesFilteredSchoolDate <- df[
          df$school %in% input$school 
          & df$week >= input$datesrange[1] 
          & df$week <= input$datesrange[2], 
        ]
      caseArea <- switch(
          input$area,
          metro = "metro_positive",
          county = "county_positive",
          state = "state_positive",
          "metro_positive"
      )
      # Create a temporary data-frame for the outputs
      df.for_ccf <- data.frame(
        positive = dfCasesFilteredSchoolDate$positive,
        placeholder = dfCasesFilteredSchoolDate[, caseArea]
      )
      colnames(df.for_ccf)[colnames(df.for_ccf) == "placeholder"] <- caseArea
      df.for_ccf <- na.omit(df.for_ccf)
      ccf(
        df.for_ccf$positive,
        df.for_ccf[, caseArea],
        main = "",
        ylab = "Correlation",
        xlab = "Lag (weeks)"
      )
    }, res = 96
  )

  output$universityAreaVaccinesCCFPlot <- renderPlot(
    {
      # should probably make this reactive.
      dfCasesFilteredSchoolDate <- df[
          df$school %in% input$school 
          & df$week >= input$datesrange[1] 
          & df$week <= input$datesrange[2], 
        ]
      caseArea <- switch(
          input$area,
          metro = "metro_vaccine",
          county = "county_vaccine",
          state = "state_vaccine",
          "metro_vaccine"
      )
      # Create a temporary data-frame for the outputs
      df.for_ccf <- data.frame(
        positive = dfCasesFilteredSchoolDate$positive,
        placeholder = dfCasesFilteredSchoolDate[, caseArea]
      )
      colnames(df.for_ccf)[colnames(df.for_ccf) == "placeholder"] <- caseArea
      df.for_ccf <- na.omit(df.for_ccf)
      ccf(
        df.for_ccf$positive,
        df.for_ccf[, caseArea],
        main = "",
        ylab = "Correlation",
        xlab = "Lag (weeks)"
      )
    }, res = 96
  )

  output$universityAreaVaccinesPlot <- renderPlot(
    { 
      dfVaccinesFilteredSchoolDate <- df[
        df$school %in% input$school 
        & df$week >= input$datesrange[1] 
        & df$week <= input$datesrange[2], 
      ]
      vaccineArea <- switch(
        input$area,
        metro = "metro_vaccine",
        county = "county_vaccine",
        state = "state_vaccine",
        "metro_vaccine"
      )
      ggplot(
        rbind(
          na.omit(
            data.frame(
              week = dfVaccinesFilteredSchoolDate$week,
              value = dfVaccinesFilteredSchoolDate$positive,
              fct = rep("school", length(dfVaccinesFilteredSchoolDate$week))
            )
          ),
          na.omit(
            data.frame(
              week = dfVaccinesFilteredSchoolDate$week,
              value = dfVaccinesFilteredSchoolDate[, vaccineArea],
              fct = rep("area", length(dfVaccinesFilteredSchoolDate$week))
            )
          )
        )
      ) + geom_line(
        aes(week, value, color = fct)
      ) + facet_wrap(~fct, scales = "free", ncol = 1) + theme(legend.position="none")
    },
    res = 96
  )

  output$xycomparison <- renderPlot(
    {
      dfFilteredSchool <- df[df$school %in% input$schoolsscat & df$week >= input$datesrangescat[1] & df$week <= input$datesrangescat[2], ]
      # Can't get ggplot to accept input$xgroup with dfFilteredSchool, 
      # so resorting to this.
      dfForCompare <- rbind(
        na.omit(
          data.frame(
            week = dfFilteredSchool$week,
            value = dfFilteredSchool[, input$xgroup],
            fct = rep(input$xgroup, length(dfFilteredSchool$week)),
            school = dfFilteredSchool$school
          )
        ),
        na.omit(
          data.frame(
            week = dfFilteredSchool$week,
            value = dfFilteredSchool[, input$ygroup],
            fct = rep(input$ygroup, length(dfFilteredSchool$week)),
            school = dfFilteredSchool$school
          )
        )
      )
      ggplot(dfForCompare) + geom_point(aes(week, value, color = school)) + facet_wrap(
        ~fct, scales = "free", ncol = 2
      ) + theme(legend.position="none")
    }, res = 96
  )

  output$xyscatterplot <- renderPlot(
    {
      dfFilteredSchool <- df[df$school %in% input$schoolsscat & df$week >= input$datesrangescat[1] & df$week <= input$datesrangescat[2], ]
      # Can't get ggplot to accept input$xgroup with dfFilteredSchool, 
      # so resorting to this.
      dfForScatter <- data.frame(
        x = dfFilteredSchool[, input$xgroup],
        y = dfFilteredSchool[, input$ygroup],
        school = dfFilteredSchool$school
      )
      ggplot(
        dfForScatter
      ) + geom_point(
        aes(x, y, color = school)
      ) + labs(x = input$xgroup, y = input$ygroup)
    }, res = 96
  )

  output$xycorrelation <- renderText(
    {
      dfFilteredSchool <- df[df$school %in% input$schoolsscat & df$week >= input$datesrangescat[1] & df$week <= input$datesrangescat[2], ]
      xycorr.pearson <- cor(
        dfFilteredSchool[, input$xgroup],
        dfFilteredSchool[, input$ygroup],
        method = "pearson",
        use = "complete.obs"
      )
      xycorr.spearman <- cor(
        dfFilteredSchool[, input$xgroup],
        dfFilteredSchool[, input$ygroup],
        method = "spearman",
        use = "complete.obs"
      )
      corrTextOutput <- paste(
          "The correlations of<b>",
          input$xgroup,
          "</b>and<b>",
          input$ygroup,
          "</b>is:<br><b>Pearson:</b>",
          round(xycorr.pearson, digits = 2),
          "<br><b>Spearman:</b>",
          round(xycorr.spearman, digits = 2)
        )
      corrTextOutput
    }
  )

  output$queryTable <- renderDataTable(
    {
      dfFilteredQuery <- df[df$school %in% input$schoolsquery & df$week >= input$datesrangequery[1] & df$week <= input$datesrangequery[2], ]
      dfFilteredQuery <- dfFilteredQuery[, colnames(dfFilteredQuery) %in% input$featurequery]
      dfFilteredQuery <- na.omit(dfFilteredQuery)
      return(dfFilteredQuery)
    },
    options = list(
      pageLength = 10
    )
  )

}

shinyApp(ui, server)
