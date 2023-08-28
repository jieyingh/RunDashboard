FROM rocker/r-ver:4.3.1

LABEL maintainer="USER huang.jie_ying@computationalgenomics.ca"

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    libssl-dev \
    libssh2-1-dev \
    libxml2-dev
RUN R -e "install.packages(c('shiny','shinythemes','ggplot','RSQLite','dplyr','DT'))"
RUN R -e "install.packages('highcharter', repos='http://cran.rstudio.com/')"

WORKDIR /home/app/

COPY RunDashboard/data/runData.db /home/app/data/runData.db
COPY RunDashboard/www/dino.png /home/app/www/dino.png
COPY RunDashboard/app.R /home/app

CMD ["R", "-e", "shiny::runApp('/home/app', host='0.0.0.0', port=3838)"]
EXPOSE 3838
