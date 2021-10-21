bib_data <- jsonlite::read_json("docs/bib-data.json")

string_to_tmp <- function(x) {
  tmp <- tempfile()
  cat(x, sep = "\n", file = tmp)
  tmp
}

expand_genera <- function(x) {
  abbr <- grep("^[A-Z]\\.", x)
  if (!length(abbr)) return(x)
  for (i in seq_along(abbr)) {
    if ((abbr[[i]] - 1L) %in% c(0L, abbr)) next
    genus <- strsplit(x[[abbr[[i]] - 1L]], " ")[[1L]][[1L]]
    x[[abbr[[i]]]] <- gsub("^[A-Z]\\.", genus, x[[abbr[[i]]]])
    abbr[[i]] <- NA_integer_
  }
  x
}

titles <- vapply(bib_data, getElement, character(1), "title")
names  <- namext::name_extract(string_to_tmp(titles))$names$name
names  <- expand_genera(names)

resolved_names <- taxize::gnr_resolve(
  names, data_source_ids = c(3, 11, 12, 165), best_match_only = TRUE,
  fields = "all"
)
