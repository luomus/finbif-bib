#!/bin/bash
echo "bibuser:x:$(id -u):0:bibuser user:/home/bibuser:/sbin/nologin" >> /etc/passwd
git config --global user.email $GIT_EMAIL
git config --global user.name $GIT_USER
cp -p keys/id_ed25519 .ssh/id_ed25519
chmod 0600 .ssh/id_ed25519
git clone git@github.com:luomus/finbif-bib
cd finbif-bib
Rscript --verbose update-bib.R
git commit -am 'Update bibliography'
git push
