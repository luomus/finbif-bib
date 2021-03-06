ptrn <- "10[.]\\d{3,9}(?:[.][0-9]+)*/[[:graph:]]+"

reduce_merge <- function(df) {
  df <- Reduce(function(x, y) merge(x, y, all = TRUE, sort = FALSE), df)
  # sometimes need 0 row dfs
  if (is.null(df)) data.frame() else df
}

extract_url <- function(x) {
  x <- rvest::html_nodes(x, "h3")
  pdfs <- lapply(x, rvest::html_nodes, "span")
  pdfs <- lapply(pdfs, rvest::html_text)
  pdfs <- grepl("pdf", lapply(pdfs, tolower))
  x <- rvest::html_nodes(x, "a")
  x <- rvest::html_attrs(x)
  x <- lapply(x, getElement, "href")
  x <- lapply(x, urltools::param_get)
  x <- reduce_merge(x)
  x <- as.list(x[["url"]])
  for (i in seq_along(pdfs)) {
    attr(x[[i]], "pdf") <- pdfs[[i]]
  }
  x
}

extract_doi <- function(txt, ptrn) {
  doi <- stringr::str_extract_all(txt, ptrn)
  if (length(unlist(doi))) doi <- unlist(doi)[[1L]] else doi <- NA
  if (grepl(ptrn, doi[[1L]])) doi[[1]] else NA
}

get_doi <- function(x) {
  txt <- rvest::html_text(x)
  doi <- extract_doi(txt, ptrn)
  if (!is.na(doi)) return(doi)
  urls <- extract_url(x)
  doi <- extract_doi(urls, ptrn)
  if (!is.na(doi)) return(doi)
  lapply(urls, get_doi_from_url)
}

get_doi_from_url <- function(url) {

  if (is.null(url)) return(NA)
  if (attr(url, "pdf")) {
    tmpfile <- tempfile()
    dl <- try(download.file(url, tmpfile, quiet = TRUE), silent = TRUE)
    if (!inherits(dl, "try-error")) {
      pdf <- try(crminer::crm_extract(tmpfile), silent = TRUE)
      if (!inherits(pdf, "try-error")) {
        doi <- pdf$info$keys$doi
        if (length(doi) && grepl(ptrn, doi)) return(doi)
        doi <- extract_doi(pdf$text, ptrn)
        if (!is.na(doi)) return(doi)
      }
    }
  }
  x <- system(paste("curl -s -L -b cookies.txt", URLdecode(url)), intern = TRUE)
  x <- try(xml2::read_html(paste(x, collapse = "")), silent = TRUE)
  if (inherits(x, "try-error")) return(NA)
  doi <- rvest::html_node(x, 'meta[name="citation_doi"]')
  doi <- rvest::html_attr(doi, "content")
  if (grepl(ptrn, doi[[1L]])) return(doi[[1L]])
  x <- rvest::html_text(x)
  extract_doi(x, ptrn)

}

get_bib <- function(x) {
  if (is.na(x)) return(NA)
  Sys.sleep(1L)
  x <- httr::RETRY(
    "GET", "https://www.doi2bib.org/2/doi2bib", query = list(id = x)
  )
  x <- httr::content(x, type = "text", encoding = "UTF-8")
  x <- gsub("\\{\\\\textendash\\}", " – ", x)
  x <- gsub("\\{\\\\textemdash\\}", "—", x)
  tmpfile <- tempfile(fileext = ".bib")
  writeLines(x, tmpfile)
  tryCatch(
    rmarkdown::pandoc_citeproc_convert(tmpfile)[[1L]],
    error = function(e) NA
  )
}

fmt_bib <- function(bib) {
  if (length(bib) == 1L && is.na(bib)) return(bib)
  bib$title <- tools::toTitleCase(tolower(bib$title))
  bib$title <- gsub(" – ", "–", bib$title)
  bib$year  <- bib$issued$`date-parts`[[1L]][[1L]]
  if (length(bib$issued$`date-parts`[[1L]]) > 1L)
    bib$month <- month.name[bib$issued$`date-parts`[[1L]][[2L]]]
  bib$issued <- NULL
  bib$id <- bib$DOI
  bib$dateAdded <- format(Sys.Date())
  for (i in seq_along(bib$author)) {
    if (hasName(bib$author[[i]], "dropping-particle")) {
      bib$author[[i]]$family <- paste(
        bib$author[[i]]$`dropping-particle`, bib$author[[i]]$family
      )
      bib$author[[i]]$`dropping-particle` <- NULL
    }
  }
  stats::setNames(bib, snakecase::to_lower_camel_case(names(bib)))
}

feed_url <- Sys.getenv("FEED_URL")

res <- tryCatch(
  {
    feed <- try(
      tidyRSS::tidyfeed(feed_url, list = TRUE, clean_tags = FALSE),
      silent = TRUE
    )
    if (!inherits(feed, "try-error")) {

      articles <- feed$entries$item_description
      articles <- lapply(articles, xml2::read_html)

      bib_data <- lapply(articles, get_doi)
      bib_data <- unlist(bib_data)
      bib_data <- lapply(bib_data, get_bib)
      bib_data <- bib_data[!is.na(bib_data)]
      bib_data <- lapply(bib_data, fmt_bib)

      bib_data <- c(jsonlite::read_json("docs/bib-data.json"), bib_data)

      ids <- vapply(bib_data, getElement, character(1L), "id")

      bib_data <- bib_data[
        !duplicated(ids) &
        !ids %in% readLines("blacklist.txt")
      ]

      bib_data <- bib_data[
        order(
          vapply(bib_data, getElement, integer(1L), "year"),
          vapply(
            bib_data,
            function(x) {
              if (utils::hasName(x, "month")) {
                m <- getElement(x, "month")
                grep(m, month.name)
              } else {
                0L
              }
            },
            integer(1L)
          ),
          decreasing = TRUE
        )
      ]

      cat(xfun::tojson(bib_data), file = "docs/bib-data.json")
    }
    "success"
  },
  error = function(e) return("fail")
)

cat(res, file = "docs/status.txt")
cat(format(Sys.time(), usetz = TRUE), file = "docs/last-updated.txt")
