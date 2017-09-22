FROM rocker/shiny:latest

RUN apt-get update
RUN apt-get install -y libmysqlclient-dev
# 日本語フォントのインストール
RUN apt-get install -y fonts-ipafont-gothic

RUN R -e "install.packages(c('config', 'DBI', 'RMySQL', 'dplyr', 'DT'), repos='https://cran.rstudio.com/')"

COPY *.R /srv/shiny-server/goat/
COPY config.yml /srv/shiny-server/goat/

EXPOSE 3838
CMD ["/usr/bin/shiny-server.sh"]
