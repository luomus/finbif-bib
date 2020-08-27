feed_url <- Sys.getenv("FEED_URL")
feed     <- tidyRSS::tidyfeed(feed_url, list = TRUE, clean_tags = FALSE)
articles <- feed$entries$item_description
articles <- lapply(feed$entries$item_description, xml2::read_html)

extract_url <- function(x) {
  x <- rvest::html_node(x, "h3 a")
  x <- rvest::html_attrs(x)
  x <- x["href"]
  x <- urltools::param_get(x)
  x <- x[1L, "url"]
}

is_pdf <- function(x) {
  x <- rvest::html_node(x, "h3 span")
  x <- rvest::html_text(x)
  grepl("pdf", tolower(x))
}

get_doi <- function(x) {
  ptrn <- "10[.]\\d{3,9}(?:[.][0-9]+)*/[[:graph:]]+"
  url <- extract_url(x)
  if (is.null(url)) return(NA)
  if (is_pdf(x)) {
    tmpfile <- tempfile()
    download.file(url, tmpfile, quiet = TRUE)
    pdf <- crminer::crm_extract(tmpfile)
    doi <- pdf$info$keys$doi
    if (length(doi) && grepl(ptrn, doi)) return(doi)
    doi <- stringr::str_extract_all(pdf$text, ptrn)
    doi <- unlist(doi)[[1]]
    if (grepl(ptrn, doi)) return(doi)
  }
  x <- xml2::read_html(url)
  x <- rvest::html_node(x, 'meta[name="citation_doi"]')
  rvest::html_attr(x, "content")
}

get_bib <- function(x) {
  doi <- get_doi(x)
  if (is.na(doi)) return(NA)
  x <- httr::GET("https://www.doi2bib.org/2/doi2bib", query = list(id = doi))
  x <- httr::content(x, type = "text", encoding = "UTF-8")
  tmpfile <- tempfile(fileext = ".bib")
  writeLines(x, tmpfile)
  rmarkdown::pandoc_citeproc_convert(tmpfile)[[1L]]
}

fmt_bib <- function(bib) {
  if (length(bib) == 1L && is.na(bib)) return(bib)
  bib$title <- tools::toTitleCase(bib$title)
  bib$year  <- bib$issued$`date-parts`[[1L]][[1L]]
  bib$month <- month.name[bib$issued$`date-parts`[[1L]][[2L]]]
  ind       <- head(seq_along(bib$author), -1L)
  if (length(ind) == 0L) return(bib)
  for (i in ind) bib$author[[i]]$family <- paste0(bib$author[[i]]$family, ",")
  bib$author[[i]]$family <- gsub(",", " &", bib$author[[i]]$family)
  bib
}

bibtex <- lapply(articles, get_bib)
bibtex <- bibtex[!is.na(bibtex)]
bibtex <- lapply(bibtex, fmt_bib)

years <- vapply(bibtex, getElement, integer(1L), "year")
bibtex <- bibtex[
  order(
    years,
    vapply(
      bibtex,
      function(x) grep(getElement(x, "month"), month.name),
      integer(1L)
    ),
    decreasing = TRUE
  )
]
bibtex <- split(bibtex, years)
bibtex <- lapply(
  names(bibtex), function(x)
  list('year-title' = x, 'year-pubs' = bibtex[[x]])
)

tmplt <-
'
<!doctype html>

<html lang="en">
<head>
  <meta charset="utf-8">

  <title>FinBIF Publications</title>
  <meta name="description" content="Publications that use or mention FinBIF data or services">
  <meta name="author" content="FinBIF">
  <style>
    html {
      font-size: 62.5%;
    }
    body {
      font-size: 1.5em;
      line-height: 1.6;
      font-weight: 400;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Fira Sans", "Droid Sans", "Helvetica Neue", sans-serif;
      color: #222;
    }
    .container {
      position: relative;
      width: 100%;
      max-width: 800px;
      margin: 0 auto;
      padding: 0 20px;
      box-sizing: border-box;
    }
    @media (min-width: 400px) {
      .container {
        width: 85%;
        padding: 0;
      }
    }
    @media (min-width: 550px) {
      .container {
        width: 80%;
      }
    }
    h1, h2, h3 {
      margin-top: 0;
      margin-bottom: 2rem;
      font-weight: 300;
    }
    h1 {
      font-size: 4.0rem;
      line-height: 1.2;
      letter-spacing: -.1rem;
    }
    h2 {
      font-size: 3.6rem;
      line-height: 1.25;
      letter-spacing: -.1rem;
    }
    h3 {
      font-size: 3.0rem;
      line-height: 1.3;
      letter-spacing: -.1rem;
    }
    @media (min-width: 550px) {
      h1 {
        font-size: 5.0rem;
      }
      h2 {
        font-size: 4.2rem;
      }
      h3 {
        font-size: 3.6rem;
      }
    }
    p {
      margin-top: 0;
      margin-bottom: 2.5rem;
    }
    a {
      color: #1EAEDB;
    }
    a:hover {
      color: #0FA0CE;
    }
    .container:after {
      content: "";
      display: table;
      clear: both;
    }
  </style>

</head>

<body>
  <div class="container">
  <h1>FinBIF Publications</h1>
  {{#bib}}
  <div class="publication-year">
    <h2>{{year-title}}</h2>
    {{#year-pubs}}
    <div class="publication">
      <h3><a href="{{URL}}" target="_blank"><span class="publication-title">{{title}}</span> (<span class="publication-month">{{month}}</span>, <span class="publication-year">{{year}}</span>)</a></h3>
      <p>
        <span class="author-name">{{#author}}{{given}} {{family}} {{/author}}</span><br>
        <span class="publication-journal">{{container-title}}<span> <span class="publication-volume">{{volume}}</span>:<span class="publication-pages">{{page}}</span><br>
        <span class="publication-doi">DOI:{{DOI}}</span><br>
      </p>
    </div>
    {{/year-pubs}}
  </div>
  {{/bib}}
  </div>
</body>
</html>
'

out <- whisker::whisker.render(tmplt, list(bib = bibtex))

cat(out, file = "publications.html")
