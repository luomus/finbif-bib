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
  bib$issued <- NULL
  bib$id <- bib$DOI
  stats::setNames(bib, snakecase::to_lower_camel_case(names(bib)))
}

bibtex <- lapply(articles, get_bib)
bibtex <- bibtex[!is.na(bibtex)]
bibtex <- lapply(bibtex, fmt_bib)

httpuv::runServer("0.0.0.0", 5000,
  list(
    call = function(req) {
      list(
        status = 200L,
        headers = list(
          'Content-Type' = 'application/json'
        ),
        body = xfun::tojson(bibtex)
      )
    }
  )
)
