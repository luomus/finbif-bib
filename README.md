# finbif-bib
Automated FinBIF bibliography for display on laji.fi

# Requirements
Deploy key for this repository and local copies of the following software:
```
docker
docker-compose
```

# Update
```
docker run -v "$HOME/finbif-bib/keys:/home/bibuser/keys" -e FEED_URL=$FEED_URL -e GIT_USER=$GIT_USER -e GIT_EMAIL=$GIT_EMAIL ghcr.io/luomus/finbif-bib
```
