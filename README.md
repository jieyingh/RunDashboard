# run_processing_dashboard
Extracts run metrics from multiQC json files, stores them in a database, and displays them in a dashboard

## Usage
### Data extraction

### Setting up
### Importing data to database
### Dashboard
Open dashboard.R in Rstudio, then click on Run App on top right of script. Need to have shiny installed.

## Data sources and calculations
### Extraction
All metrics are extracted and calculated from multiQC json files. The json parser has been written to extract data from multiQC json files issued from Freezeman, using C3G's custom template. They are then stored in a simple sqlite3 database contained in the data folder called runData.db.
**size**


*insert image of database structure*

**entry_id** <br>
Only shown in database and full data table. Is used to distinguish each entry in the databased. The entry ID is composed of the project ID and run ID.

**project_id** <br>
ID of project. Different runs may contain the same project ID.

**run** <br>
Run identifier. A run could contain multiple project IDs. Run ID is extracted from header of multiQC.

## Possible issues
### Database connection
### Parsing
### Dashboard

## Libraries
### R
<p>
The Shiny app was built with the following: <br>
R version 4.3.0 (2023-04-21)  <br>
DT_0.28 <br>
shinythemes_1.2.0 <br>
highcharter_0.9.4 <br>
ggplot2_3.4.2 <br>    
RSQLite_2.3.1 <br>    
dplyr_1.1.2 <br>
shiny_1.7.4 <br>

### Python
