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
docker pull ghcr.io/luomus/finbif-bib

docker run -v "$HOME/finbif-bib/ssh:/root/.ssh" -e FEED_URL=$FEED_URL -e GIT_USER=$GIT_USER -e GIT_EMAIL=$GIT_EMAIL ghcr.io/luomus/finbif-bib
```

# Serve
```
docker-compose up -d
```

* Content will be served at `http://localhost:8080/bib-data.json`
* Status served at `http://localhost:8080/status.txt`

# Stop
```
docker-compose down
```
