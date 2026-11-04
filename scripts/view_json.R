args <- commandArgs(trailingOnly = TRUE)
open_browser <- !"--no-open" %in% args
files <- args[args != "--no-open"]
if (!length(files)) stop("Usage: Rscript scripts/view_json.R [--no-open] file.json [another.json]")
root <- rprojroot::find_root(rprojroot::has_file("DESCRIPTION"))
records <- lapply(files, function(path) {
  if (!file.exists(path)) stop("File not found: ", path)
  contents <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!jsonlite::validate(contents)) stop("Invalid JSON: ", path)
  list(name = basename(path), text = contents)
})
payload <- jsonlite::toJSON(records, auto_unbox = TRUE)
encoded <- jsonlite::base64_enc(charToRaw(enc2utf8(payload)))
template <- readLines(file.path(root, "tools", "json_viewer.html"), warn = FALSE)
placeholder <- '<script id="initial-data" type="application/octet-stream"></script>'
stopifnot(sum(template == placeholder) == 1L)
template[template == placeholder] <- paste0(
  '<script id="initial-data" type="application/octet-stream">', encoded, "</script>"
)
output <- file.path(root, "data", "build", "json_viewer.html")
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
writeLines(template, output, useBytes = TRUE)
cat(output, "\n")
if (open_browser) utils::browseURL(paste0("file://", output))
