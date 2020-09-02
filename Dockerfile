FROM bitnami/minideb:unstable

RUN  echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/90local-no-recommends

RUN  apt-get update \
  && apt-get install -y \
       libpoppler-cpp-dev \
       pandoc-citeproc \
       python3-apt \
       r-base-dev

RUN  R -e "install.packages('bspm')" \
  && echo "bspm::enable()" >> /etc/R/Rprofile.site \
  && R -e "install.packages(c('crminer', 'rmarkdown', 'rvest', 'tidyRSS', 'urltools', 'whisker'))"

COPY auto-bib.R auto-bib.R
COPY template.html template.html
COPY www/publications.css www/publications.css

ENTRYPOINT ["R", "-e", "source('auto-bib.R')"]
