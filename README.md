# finbif-bib
Automated FinBIF bibliography for display on laji.fi

# Requirements
Write access to this repository and local copies of the following software:
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

docker pull ghcr.io/luomus/finbif-bib

docker run --volume="$HOME/finbif-bib/www:/www" FEED_URL=$FEED_URL ghcr.io/luomus/finbif-bib

git commit -am 'Update bibliography'

git push
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
