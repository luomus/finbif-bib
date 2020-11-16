#!/bin/bash
git config --global user.email $GIT_EMAIL
git config --global user.name $GIT_USER
mkdir /root/.ssh
cp -p keys/id_ed25519 /root/.ssh/id_ed25519
cp -p known_hosts /root/.ssh/known_hosts
git clone git@github.com:luomus/finbif-bib
cd finbif-bib
Rscript --verbose update-bib.R
git commit -am 'Update bibliography'
git push
