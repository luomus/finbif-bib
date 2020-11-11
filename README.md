# finbif-bib
Automated FinBIF bibliography

# Requirements
```
git
docker
docker-compose
```

# Install
```
cd $HOME
git clone https://github.com/luomus/finbif-bib
```

# Update
```
cd finbif-bib

git pull

docker run --volume="$HOME/finbif-bib/www:/www" FEED_URL=$FEED_URL ghcr.io/luomus/finbif-bib
```

# Serve
```
docker-compose up -d
```
Content will be served at `http://localhost:8080/bib-data.json`

# Stop
```
docker-compose down
```
