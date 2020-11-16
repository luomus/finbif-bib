extract_url <- function(x) {
  x <- rvest::html_node(x, "h3 a")
  x <- rvest::html_attrs(x)
  x <- x["href"]
  x <- urltools::param_get(x)
  x[1L, "url"]
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
    if (length(unlist(doi))) doi <- unlist(doi)[[1L]]
    if (grepl(ptrn, doi[1L])) return(doi)
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
  x <- gsub("\\{\\\\textendash\\}", " – ", x)
  x <- gsub("\\{\\\\textemdash\\}", "—", x)
  tmpfile <- tempfile(fileext = ".bib")
  writeLines(x, tmpfile)
  rmarkdown::pandoc_citeproc_convert(tmpfile)[[1L]]
}

fmt_bib <- function(bib) {
  if (length(bib) == 1L && is.na(bib)) return(bib)
  bib$title <- tools::toTitleCase(tolower(bib$title))
  bib$title <- gsub(" – ", "–", bib$title)
  bib$year  <- bib$issued$`date-parts`[[1L]][[1L]]
  bib$month <- month.name[bib$issued$`date-parts`[[1L]][[2L]]]
  bib$issued <- NULL
  bib$id <- bib$DOI
  stats::setNames(bib, snakecase::to_lower_camel_case(names(bib)))
}

feed_url <- Sys.getenv("FEED_URL")

res <- tryCatch(
  {
    feed     <- tidyRSS::tidyfeed(feed_url, list = TRUE, clean_tags = FALSE)
    articles <- feed$entries$item_description
    articles <- lapply(feed$entries$item_description, xml2::read_html)

    bib_data <- lapply(articles, get_bib)
    bib_data <- bib_data[!is.na(bib_data)]
    bib_data <- lapply(bib_data, fmt_bib)

    bib_data <- c(jsonlite::read_json("docs/bib-data.json"), bib_data)

    dois <- vapply(bib_data, getElement, character(1L), "doi")

    bib_data <- bib_data[
      !duplicated(dois) &
      !dois %in% readLines("blacklist.txt")
    ]

    bib_data <- bib_data[
      order(
        vapply(bib_data, getElement, integer(1L), "year"),
        vapply(
          bib_data,
          function(x) grep(getElement(x, "month"), month.name),
          integer(1L)
        ),
        decreasing = TRUE
      )
    ]

    cat(xfun::tojson(bib_data), file = "docs/bib-data.json")
    "success"
  },
  error = function(e) return("fail")
)

cat(res, file = "docs/status.txt")
cat(format(Sys.time(), usetz = TRUE), file = "docs/last-updated.txt")