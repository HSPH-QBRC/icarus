library(shiny)
library(ggplot2)
library(GGally)
library(MASS)
library(jtools)
library(reshape2)
library(httr)
library(readr)

loadData <- function() {
  # get CSV data from ISO weeks REST API and return as a data frame
  response = GET("https://webhooks.mongodb-realm.com/api/client/v2.0/app/dev-icarus-mzcsi/service/export/incoming_webhook/report")
  return(as.data.frame(content(response)))
}

df <- loadData()

df.uni <- df[! df$school %in% c("MA public schools", "Boston-area public schools"),]

tmp_df <- df.uni[, which(
  names(df.uni) %in% c(
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

df.uni$school <- factor(df.uni$school)
df.uni$school <- relevel(df.uni$school, ref = "Harvard")

fit <- glm.nb(
  positive ~ week + total + school + county_positive + school:week + county_positive:week,
  data = df.uni
)

for_pred <- df.uni[, which(
  names(df.uni) %in% c(
    "week", "county_positive", "county_density", "total", "school"
  )
)]
pred_vals <- exp(predict(fit, newdata=for_pred))
new_df <- df.uni
new_df$predicted <- pred_vals

df.boston <- df[df$school %in% c(
  "Harvard", "Northeastern", "BC",
  "Boston-area public schools", "MA public schools"
),]

df.compare <- df.boston[, which(
  names(df) %in% c("school", "county_positive", "positive", "total", "week")
)]
df.compare[, 3] <- log(df.compare[,3] + 1)
df.cast <- dcast(
  df.compare,
  week ~ school,
  value.var = "positive",
  fun.aggregate = mean,
  na.rm = F
)

df.compare <- merge(
  x = df[df$school == "Harvard", c("week", "positive")],
  y = df[df$school == "Boston-area public schools", c("week", "positive"),],
  by = "week"
)
colnames(df.compare) <- c("week", "Harvard", "Boston-area public schools")
df.compare <- melt(df.compare, id.vars="week")

ui <- fluidPage(
    
  titlePanel("ICARUS dashboard"),

  markdown('
    ### Analysis from the ICARUS dataset
    This was an export of data found on the ICARUS platform of a Ivy+ Consortium initiative. The data was pulled on March 2, 2021 (2021-03-02). The database represents data from a variety of sources:
    * University COVID-19 dashboards
      * Harvard
      * Boston College
      * Northeastern
      * Columbia
      * Dartmouth
      * Princeton
    * [Massachusetts Department of Elementary and Secondary Education (DESE)](https://www.doe.mass.edu/covid19/positive-cases/)
    * [CovidActNow Data API](https://covidactnow.org/data-api)

    We have normalized the data to a weekly summation, as some databases had daily data and others only weekly. In this case, we coalesced the data around a common week format. Please keep in mind that the common week may not be 100% concordant with the week definition of each database, but it will be a mostly close. In particular, the "end of week" for the Massachusetts Department of Education chose Wednesday. Other databases chose Friday, Saturday, or Sunday. Daily databases had the information summed or averaged across the week (where appropriate). Please note, these are summed week value, and not weekly windowed averages.

    #### Overview of dashboard data
    We can see that the universities tend toward an exponential growth of the positive case load as time went on.
  '),

  fluidRow(
    column(12, plotOutput("universityCasesPlot"))
  ),

  markdown('We then can adjust the y-axis to better reflect the growth on a log scale.'),

  fluidRow(
    column(12, plotOutput("universityCasesLogPlot"))
  ),

  markdown("
    #### Identification of correlative features
    There are a number of questions we may want to ask given the breadth of data in the ICARUS database:
    1. Are university positive case loads dissociated from the local environment?
    2. How do universities compare to the local environment?
    3. Are any universities particularly different in their response to distancing the students from the local environment?

    As a first pass, we compare the correlations of features we have in the ICARUS. Here we compare the pairwise correlations of:
    * university positve cases
    * county positive cases
    * county computed density of cases
    * state positive cases
    * state computed density of cases
    * metro area positive cases
    * metro area computed density of cases

    These values have been matched to each university's respective locale. When we compare a pairwise correlation of all features.       Positive case loads (whether for state, metro, county, or university) were log transformed and pairwise comparisons were performed with a Pearson correlation. The results are summarized as follows.
           
    We can see that the the state, county, and metro data is most strongly correlated. However, we also see that the county positive rate is the strongest correlate with the university case load (R = 0.742; R^2 = 0.551), even more so than week. This indicates that, while time is certainly a factor to predic the log-transformed rates, the local context of the county data is more relevant.
  "),

  fluidRow(
    column(12, plotOutput("pairwiseCorrelations"))
  ),

  markdown('We can further investigate the shape of the relationships by scatterplot.'),

  fluidRow(
    column(12, plotOutput("scatterplot", height = "800px"))
  ),

  markdown('We can see the relationship when we overlay one of the features on the positive case load graphs show previously. Here we show the related county positive case load overlaid in black and with the log transformed y-axis again.
  '),

  fluidRow(
    column(12, plotOutput("countyCasesOverlayPlot"))
  ),

  markdown('
    #### Building a predictive model

    We can then try building a GLM (general linear model) to identify the statistical signficance of the relationships between the county data and the university case load. Considering this is count data, we expect the relationship to be Poisson - likely overdispersed. Rather than using the log-transformed values, we believe it more appropriate to use a negative binomial GLM.

    We create a simple GLM of:

    `positive ~ week + total + school + county + school:week + county:week`

    where the features correspond to
    * positive = positive case tests for the university that week
    * total = total tests administered by the university that week
    * county = positive case tests for the county that week
    * week = the week
    * school = the university in question
 '),

  fluidRow(
    column(12, verbatimTextOutput("glmSummaryTable"))
  ),

  markdown('
    We can potentially take a few things from this. The county data by week is very predictive of the overall trend of data. This is a statistically significant correlation, and furthermore the slope is aproximately the same. That is, while the actual case load may differ, the trend tracks strongly and similarly. Only BC showed a specific school effect on the slope and initial load that were statistically significant. This tracks with the visualization shown earlier where BC had a very irregular pattern of positive case loads. Additionally, the county data was more predictive of the starting point of case load than any individual school and had a stronger effect that the total testing of the university.

    We can visualize how well the model predicts the school positive case load. In the following figure, the black dots represent the predicted values given the same data input (excepting the actual positive case load data).
  '),

  fluidRow(
    column(12, plotOutput("predictedCaseLoadPlot"))
  ),

  markdown('
    Despite all this, it is prudent to identify how well some of these values track as the data changes. As we can see below, while the time factors well, we see that the variance is higher early on and later. This indicates that the model predicts less well (as concerns the time factor alone) during the early stages and later stages of the dataset.
  '),

  fluidRow(
    column(12, plotOutput("weekEffectPlot"))
  ),

  markdown("
    The predictive power of the local county's positive case load also becomes more variant as the local case load increases. This increasing variance could be intrinsic to the relationship, or that the universities are displaying increasing decorrelation with the local environment as the local case load increases. This would require further investigation to confirm.
  "),

  fluidRow(
    column(12, plotOutput("countyEffectPlot"))
  ),

  markdown("
    #### Comparison to MA public schools

    We have filtered down the data set to the Boston area universities, and this time included the public school data. The plot is log-transformed on the y-axis and we have included in black the metro-area positive case load as a comparison. We can see that the Boston-based universities are similar to the Boston area public schools in trend and total positive case load. The Boston are public schools comprise of cities/towns of:
    * Boston
    * Cambridge
    * Somerville
    * Brooline
    * Newton
    * Quincy
    * Medford
    * Watertown
    * Malden
    * Everett
    * Chelsea

    We have overlaid the metro area positive case load with the Boston based universities, the Boston area public schools, and the Massachusetts public school data. Overall, they all trend together. However, we see that the universities do track well with the public schools, both in trend and total positive case load.
  "),

  fluidRow(
    column(12, plotOutput("metroCasesOverlayPlot"))
  ),

  markdown("When we compare the universities to the schools, we find that the correlation, while strong, is similar to what we saw in the universities' relationships with the local area data. This indicates that universities, while strongly correlated with the local environment, do tend to differ slightly."),

  fluidRow(
    column(12, plotOutput("schoolCorrelationsPlot"))
  ),

  markdown("When we take a closer look at the data for a single university, we see that the positive cases track well, but a few outlier events tends to skew the correlation."),

  fluidRow(
    column(12, plotOutput("publicSchoolsHarvardPlot"))
  )
)

server <- function(input, output) {

  output$universityCasesPlot <- renderPlot({
    ggplot(df.uni, aes(week, positive)) + geom_point(aes(color = school)) + facet_wrap("school")
  })

  output$universityCasesLogPlot <- renderPlot({
    ggplot(df.uni, aes(week, positive)) +
      geom_point(aes(color = school)) +
      scale_y_continuous(trans='log10') +
      facet_wrap("school")
  })

  output$pairwiseCorrelations <- renderPlot({
    ggcorr(tmp_df)
  })

  output$scatterplot <- renderPlot({
    plot(tmp_df, cex=0.5)
  })

  output$countyCasesOverlayPlot <- renderPlot({
    ggplot(df.uni, aes(week, positive)) + 
      geom_point(aes(color = school)) +
      geom_point(aes(week, county_positive)) +
      scale_y_continuous(trans='log10') +
      facet_wrap("school")
  })

  output$glmSummaryTable <- renderPrint({
    summary(fit)
  })

  output$predictedCaseLoadPlot <- renderPlot({
    ggplot(new_df, aes(week, positive)) +
      geom_point(aes(color = school)) +
      geom_point(aes(week, predicted)) +
      facet_wrap("school")
  })

  output$weekEffectPlot <- renderPlot({
    effect_plot(fit, pred = week, interval = T)
  })

  output$countyEffectPlot <- renderPlot({
    effect_plot(fit, pred = county_positive, interval = T)
  })

  output$metroCasesOverlayPlot <- renderPlot({
    ggplot(df.boston, aes(week, positive)) + 
      geom_point(aes(color = school)) + 
      geom_point(aes(week, metro_positive)) +
      scale_y_continuous(trans='log10')+
      facet_wrap("school")
  })

  output$schoolCorrelationsPlot <- renderPlot({
    ggcorr(df.cast)
  })

  output$publicSchoolsHarvardPlot <- renderPlot({
    ggplot(df.compare, aes(week, value)) + geom_point(aes(color = variable)) + scale_y_continuous(trans='log10')
  })
}

shinyApp(ui, server)
