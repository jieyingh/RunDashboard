# Load packages ----------------------------------------------------------------

library(shiny)
library(dplyr)
library(RSQLite)
library(highcharter)
library(shinythemes)
library(DT)

# Database connect -----
con <- dbConnect(RSQLite::SQLite(), "./data/runData.db")
alldf <- dbGetQuery(con, 'SELECT * FROM runs')
alldf$seqDate <- as.Date(alldf$seqDate)
dbDisconnect(con)

# UI ---------------------------------------------------------------------------

ui <- fluidPage(
  theme = shinytheme("cerulean"),
  
  titlePanel("DashRun'R"),
  
  sidebarLayout(
    
    # Inputs -------------------------------------------------------------------
    
    sidebarPanel(
      width = 4,
      
      h4("Load dataset"),
      
      helpText("To start, submit dates to view report for selected time period."),
      
      dateRangeInput(inputId = "dates",
                     label = "Choose a time frame to view"),
      
      actionButton(inputId = "submit",
                   label = "Submit dates"),
      
      checkboxInput(
        inputId = "table",
        label = "Show data table of dates selected",
        value = FALSE),
      
      br(),
      br(),
      
      h4("Graph options"),
      
      helpText("Changes metric used to plot line graph"),
      
      selectInput(
        inputId = "y",
        label = "Choose metric",
        choices = c("Number of samples" = "numSamples", 
                    "Number of bases" = "sumBases", 
                    "Average depth" = "avgDepth", 
                    "Average yield" = "avgYield", 
                    "Average duplication rate" = "avgDup", 
                    "Average Q30" = "avgQ30",
                    "Average VCF Depth" = "avgVCFDepth")),
      
      checkboxInput(
        inputId = "zero",
        label = "Set y-axis to start at 0",
        value = FALSE),
            
      br(),
      br(),
      
      h4("Download tables"),
      helpText("Download datasets generated in .csv format. Select dates first before downloading"),
      
      selectInput(
        inputId = "dldata",
        label = "Choose which dataset to download",
        choices = c("Summary table" = "summary", 
                    "Per project ID" = "projectId", 
                    "Per instrument" = "instrument", 
                    "Per sequencing type" = "seqtype",
                    "Full data table of dates selected" = "fulldata")),
      
      downloadButton("downloadData", "Download")
    ),
    
    # Outputs ------------------------------------------------------------------
    
    mainPanel(
      width = 8,
      
      # loads image before 
      conditionalPanel(
        condition = "input.submit == false",
        img(src = "dino.png")
      ),
      conditionalPanel(
        condition = "input.submit",
        highchartOutput("mainPlot"),
      # Manages tabs
        tabsetPanel(type = "tabs",
                    tabPanel("Summary", 
                             helpText("Summary of all data points within selected
                                      date range."),
                             tableOutput("summary")),
                  
                    tabPanel("Per project ID",
                             helpText("Summary grouped by project ID."),
                             tableOutput("project")),
                  
                    tabPanel("Per instrument", 
                             helpText("Summary grouped by instrument."),
                             tableOutput("instrument")),
                  
                    tabPanel("Per sequencing type",
                             helpText("Summary grouped by sequencing type."),
                           tableOutput("assay"))),
      ),
      
      DT::dataTableOutput("data")
      )
    )
  )

# SERVER -----------------------------------------------------------------------

server <- function(input, output) {
  
  #---- date selection
  runsdf <- eventReactive(input$submit, {
    alldf %>% filter(between(seqDate, input$dates[1], input$dates[2]))
  })
  
  # Plot -----------------------------------------------------------------------
  #---- df with only metrics selected
  plot_df <- reactive({
    validate(
      need(nrow(runsdf()) > 0 , "No data for period selected. Please select another date range then click 'Submit dates'")
    )
    runsdf() %>%
      select(seqDate, input$y) %>%
      rename(x_date = seqDate,
             y_metric = input$y)
  })  
  
  #---- plot subtitle
  selected_dates <- reactive({
    paste(input$dates[1], "to", input$dates[2])
  })
  
  #---- main graph
  output$mainPlot <- renderHighchart({
    hc <- highchart() %>%
      hc_add_series(data = plot_df(), 
                    type = "scatter",
                    hcaes(x = x_date, y = y_metric )) %>%
      hc_xAxis(type = "datetime", 
               dateTimeLabelFormats = list(day = '%y-%m-%d'), 
               title = list(text = "Date"))
    
    # switches the y label depending on metric selected
    y_label <- switch (input$y,
                       numSamples = "Number of samples sequenced",
                       sumBases = "Number of bases sequenced in millions of bases",
                       avgDepth = "Average sequencing depth", 
                       avgYield = "Average yield",
                       avgDup = "Average duplication rate",
                       avgQ30 = "Average q30 score",
                       avgVCFDepth = "Average depth at sites in VCF file"
    )
    
    #shows data when hovered
    tooltip <- paste("Date: {point.x:%y-%m-%d} <br>",
                     y_label,
                     ": {point.y}")
    
    # Sets y-axis to 0 if option selected
    if (input$zero){
      hc <- hc %>%
        hc_yAxis(title = list(text = y_label), min = 0)
    } else {
      hc <- hc %>%
        hc_yAxis(title = list(text = y_label))
    }
    
    # formats labels and subtitle
    hc <- hc %>%
      hc_subtitle(text = paste(y_label, "over time from", 
                               selected_dates())) %>%
      hc_title(text = y_label) %>%
      hc_tooltip(pointFormat = tooltip)
    hc
  })
  
  
  # Tables ---------------------------------------------------------------------
  #---- summary tab
  summaryTable <- reactive({
    projects <- n_distinct(runsdf()$project_id)
    runs <- n_distinct(runsdf()$run)
    samples <- sum(runsdf()$numSamples, na.rm = T)
    depth <- mean(runsdf()$avgDepth, na.rm = T)
    yield <- mean(runsdf()$avgYield, na.rm = T)
    q30 <- mean(runsdf()$avgQ30, na.rm = T)
    bases <- format(sum(runsdf()$sumBases, na.rm = T)/1000000, 2)
    dupRate <- mean(runsdf()$avgDup, na.rm = T)
    VCFDepth <- mean(runsdf()$avgVCFDepth, na.rm = T)
    
    summaryTable <- data.frame(projects, runs, samples, bases, depth, yield, q30, dupRate, VCFDepth) 
    newCols <- c("Number of projects", "Number of runs", "Total samples",
                      "Bases sequenced in millions of bases", "Average depth",
                      "Average yield", "Average q30", "Average duplication rate",
                      "Average depth at sites in VCF file")
    summaryTable <- summaryTable %>% rename(!!!setNames(names(summaryTable), newCols))
  })
  
  output$summary <- renderTable({
    summaryTable()
  })
  
  #---- per project id tab
  projectTable <- reactive({
    projectTable <- runsdf() %>% group_by(project_id) %>% 
      summarise(
        runs = n_distinct(run),
        samples = sum(numSamples, na.rm = T),
        bases = format(sum(sumBases, na.rm = T)/1000000, 2),
        depth = mean(avgDepth, na.rm = T),
        yield = mean(avgYield, na.rm = T),
        q30 = mean(avgQ30, na.rm = T),
        dupRate = mean(avgDup, na.rm = T),
        VCFDepth = mean(avgVCFDepth, na.rm = T)
      )
    
    newCols <- c("Project ID", "Number of runs", "Total samples",
                 "Bases sequenced in millions of bases", "Average depth",
                 "Average yield", "Average q30", "Average duplication rate",
                 "Average depth at sites in VCF file")
    projectTable <- projectTable %>% rename(!!!setNames(names(projectTable), newCols))
  })
  
  output$project <- renderTable({
    projectTable()
  })
  
  
  #---- per instrument tab
  instrumentTable <- reactive({
    instrumentTable <- runsdf() %>% group_by(instrument) %>% 
      summarise(
        runs = n_distinct(run),
        samples = sum(numSamples, na.rm = T),
        bases = format(sum(sumBases, na.rm = T)/1000000, 2),
        depth = mean(avgDepth, na.rm = T),
        yield = mean(avgYield, na.rm = T),
        q30 = mean(avgQ30, na.rm = T),
        dupRate = mean(avgDup, na.rm = T),
        VCFDepth = mean(avgVCFDepth, na.rm = T)
      )
    
    newCols <- c("Instrument ID", "Number of runs", "Total samples",
                 "Bases sequenced in millions of bases", "Average depth",
                 "Average yield", "Average q30", "Average duplication rate",
                 "Average depth at sites in VCF file")
    instrumentTable <- instrumentTable %>% rename(!!!setNames(names(instrumentTable), newCols))
  })
  
  output$instrument <- renderTable({
    instrumentTable()
  })
  
  
  #---- per seqtype tab
  assayTable <- reactive({
    assayTable <- runsdf() %>% group_by(seqtype) %>% 
      summarise(
        runs = n_distinct(run),
        samples = sum(numSamples, na.rm = T),
        bases = format(sum(sumBases, na.rm = T)/1000000, 2),
        depth = mean(avgDepth, na.rm = T),
        yield = mean(avgYield, na.rm = T),
        q30 = mean(avgQ30, na.rm = T),
        dupRate = mean(avgDup, na.rm = T),
        VCFDepth = mean(avgVCFDepth, na.rm = T)
      )
    
    newCols <- c("Sequencing type", "Number of runs", "Total samples",
                 "Bases sequenced in millions of bases", "Average depth",
                 "Average yield", "Average q30", "Average duplication rate",
                 "Average depth at sites in VCF file")
    assayTable <- assayTable %>% rename(!!!setNames(names(assayTable), newCols))
  })
  
  output$assay <- renderTable({
    assayTable()
  })
  
  #---- shows datatable of what was selected
  output$data <- DT::renderDataTable({
    if (input$table){
      DT::datatable(
        runsdf(), escape = FALSE,
        caption = "If too large to be fully displayed, click anywhere inside
        table then use arrow keys for horizontal scrolling",
        options = list(
          scrollX = TRUE
        )
      )
       }
  })

  # Downloads ------------------------------------------------------------------
  downldata <- reactive({
    switch (input$dldata,
            summary = summaryTable(),
            projectId = projectTable(),
            instrument = instrumentTable(),
            seqtype = assayTable(),
            fulldata = runsdf())
  })
  
  #creates the download file name
  filename <- reactive({
    paste(input$dldata, input$dates[1], "_to_", input$dates[2], ".csv", sep = "")
  })
  
  #downloads the data
  output$downloadData <- downloadHandler(
    filename = function() {
      paste(filename())},
    content = function(file) {
      write.csv(downldata(), file)
    })
}

# Create a Shiny app object ----------------------------------------------------

shinyApp(ui = ui, server = server)
