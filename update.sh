#!/bin/bash
git config --global user.email $GIT_EMAIL
git config --global user.name $GIT_USER
git clone git@github.com:luomus/finbif-bib
cd finbif-bib
Rscript --verbose update-bib.R
git commit -am 'Update bibliography'
git push
