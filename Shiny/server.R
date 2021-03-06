require(dplyr)
library(ggplot2)
library(ggvis)
library(plotly)
library(RColorBrewer)

neighborhood <- taxidata$Neighborhood
names(neighborhood) <- as.character(taxidata$Zipcode)

function(input, output, session){
  
  nyczipcodecount <- reactive({
    
    date_input <- as.numeric(which(numbers_date$date == as.character(input$slt_date)) -1)
    # isolate(input$hour <- unique(input$hour))
    
    if(length(date_input) == 0)
      date_input <- 0

    count_tojoin <- taxidata
    if(!is.null(input$hour)) {
      count_tojoin <- count_tojoin %>%
        filter(Hour == input$hour)
    }
    count_tojoin = count_tojoin %>%
      filter(DayofWeek == as.character(date_input)) %>%
      # filter(Hour == input$hour) %>%
      group_by(Zipcode) %>%
      summarise(Total = sum(Count)) %>%
      mutate(Zipcode=factor(Zipcode))

    # nyczipcode@data = merge(x = nyczipcode@data, y = count_tojoin,
    #                         by.x='GEOID10', by.y='Zipcode', all.x = TRUE)
    
    total <- count_tojoin$Total
    names(total) <- count_tojoin$Zipcode
    nyczipcodecount <- nyczipcode
    nyczipcodecount@data$Total <- total[as.character(nyczipcode@data$GEOID10)]
    nyczipcodecount
    
  })
  ## Street and Choropleth Map
  # Create and join instant time variable to map shapefile
  # colour palette mapped to data
  

  
  output$map <- renderLeaflet({
    # Join predicted count to map shapfile
    
    x <- nyczipcodecount()@data$Total * 10^6 / nyczipcodecount()@data$ALAND10
    x_unique <- unique(x[!is.na(x)])
    colPal <- colorRampPalette(c('white', 'darkgreen'))(length(x_unique))
    names(colPal) <- sort(x_unique)
    
    cols <- ifelse(is.na(x), "#808080", colPal[as.character(x)])
    
    zipcodes <- as.character(nyczipcodecount()@data$GEOID10)
    count_popup <- paste0("<strong>NBH: </strong>", 
                          neighborhood[zipcodes],
                          "<br><strong>Zip Code: </strong>",
                          zipcodes,
                          "<br><strong>Count: </strong>",
                          round(nyczipcodecount()@data$Total/3, digits = 0),
                          "<br><strong>Density: </strong>",
                          round(x, digits = 3),
                          " per sq km"
    )
    
    basemap <- leaflet() %>%
      # leaflet::addTiles() %>%
      addProviderTiles("CartoDB.Positron") %>% 
      addPolygons(data=nyczipcodecount(),
                           fillColor = cols,
                           fillOpacity = 0.8,
                           color = "#BDBDC3",
                           stroke = TRUE,
                           weight = 2,
                           layerId = nyczipcodecount()@data$GEOID10,
                  popup = count_popup) %>%
      # addMarkers(lng = -73.97,lat = 40.74) %>%
      setView(lng = -73.97,lat = 40.74, zoom = 13)
    basemap
    })
  
  # Record markers on plot
  click_event <- reactiveValues()
  
  observeEvent(input$map_shape_click, {
    event <- input$map_shape_click

    if (is.null(event))
      return()

    leafletProxy("map") %>%
      addMarkers(lng=event$lng, lat=event$lat)

    isolate(click_event$Zipcode <- unique(c(click_event$Zipcode, event$id)))
    # print(click_event$Zipcode)

  })

  # observe(print(input$slt_date))
  # observe(print(typeof(as.character(input$slt_date))))

 # Record marker stats
 reactive({

   pt <- click_event$Zipcode
   date_input <- as.numeric(which(numbers_date$date == as.character(input$slt_date)) -1)
   sl <- input$slt_ptype
   hr <- input$hour

   if(is.null(taxidata)|is.null(pt)|is.null(input$slt_date)){
     p <- data.frame(x=1,y=1) %>%
       ggvis(~x,~y) %>%
       layer_points()
   } else {

     if(sl=='Model Compare'){
       p = taxidata %>%
         filter(DayofWeek %in% date_input) %>%
         filter(Zipcode %in% pt) %>%
         filter(Hour %in% input$hour) %>%
         group_by(Zipcode,Hour,Type) %>%
         summarise(sum(Count)) %>%
         mutate(Zipcode_new = factor(Zipcode)) %>%
         mutate(Type_Zipcode = factor(paste(Type, Zipcode_new))) %>%
         ggvis(x=~Type_Zipcode, y=~`sum(Count)`, fill=~Zipcode_new) %>%
         layer_bars(stack = FALSE) %>%
         add_axis("x", title = "Zip Code", title_offset = 50) %>%
         add_axis("y", title = "Count", title_offset = 50) %>% 
         add_legend("fill", title = "Zip Code")
       p
     }

     else{  # (sl=='Timeseries')
       p = taxidata %>%
         filter(DayofWeek %in% date_input) %>%
         filter(Zipcode %in% pt) %>%
         group_by(Zipcode, Hour) %>%
         summarise(sum(Count)) %>%
         mutate(Zipcode_new = factor(Zipcode)) %>%
         ggvis(~Hour, ~`sum(Count)`, stroke=~Zipcode_new, strokeWidth := 3) %>%
         layer_lines() %>% scale_ordinal("stroke",
         range = brewer.pal(7, "Set1"))
       p
     }


     }
   }) %>% bind_shiny(plot_id = "P")

 
 observeEvent(input$btn_clr,{
   
   leafletProxy('map') %>%
     clearMarkers()
   
   click_event$Zipcode <- NULL
 })
 

  output$plot_type <- renderUI({

    selectInput('slt_ptype',label = NULL,
                choices = c('Model Compare','Time Series'),selectize = F)

  })

  output$hour_output <- renderUI({
    
    sliderInput("hour", "Hour",
                min=0, max=23, value=0)
    
  })
  
  output$plot_UI <- renderUI({
    absolutePanel(id = "controls",
                  bottom = 60,
                  right = 10,
                  draggable = T,
                  width='auto',
                  height='auto',
                  ggvisOutput(plot_id = "P"))
  })


  ## Data Table
  output$table <- renderDataTable({
    taxidata})


}





