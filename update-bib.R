bib_data <- ""

get_bib <- function(x) {
  if (is.na(x)) return(NA)
  Sys.sleep(1L)
  x <- httr::RETRY(
    "GET", "https://www.doi2bib.org/8350e5a3e24c153df2275c9f80692773/doi2bib",
    query = list(id = x)
  )
  x <- httr::content(x, type = "text", encoding = "UTF-8")
  x <- gsub("\\{\\\\textendash\\}", " – ", x)
  x <- gsub("\\{\\\\textemdash\\}", "—", x)
  x <- strsplit(x, ",")
  x[[1L]][[1L]] <- gsub("\\s", "", x[[1L]][[1L]])
  x <- paste(x[[1L]], collapse = ",")
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

bib_data <- lapply(bib_data, get_bib)
bib_data <- bib_data[!is.na(bib_data)]
bib_data <- lapply(bib_data, fmt_bib)

bib_data <- c(jsonlite::read_json("docs/bib-data.json"), bib_data)

ids <- vapply(bib_data, getElement, character(1L), "id")

bib_data <- bib_data[!duplicated(ids)]

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
cat(format(Sys.time(), usetz = TRUE), file = "docs/last-updated.txt")
