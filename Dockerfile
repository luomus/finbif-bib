FROM bitnami/minideb:unstable

RUN  echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/90local-no-recommends

RUN  apt-get update \
  && apt-get install -y \
       git \
       libpoppler-cpp-dev \
       locales \
       openssh-client \
       pandoc-citeproc \
       python3-apt \
       r-base-dev

RUN  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen en_US.utf8 \
  && /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

RUN  R -e "install.packages('bspm')" \
  && echo "bspm::enable()" >> /etc/R/Rprofile.site \
  && R -e "install.packages(c('crminer', 'rmarkdown', 'rvest', 'snakecase', 'tidyRSS', 'urltools', 'whisker'))"

RUN mkdir www

COPY update.sh update.sh
COPY update-bib.R update-bib.R
COPY blacklist.txt blacklist.txt

ENTRYPOINT ["./update.sh"]
