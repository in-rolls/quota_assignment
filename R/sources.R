read_source <- function(source_root, state, source_lock) {
  path <- file.path(source_root, "data", "master", paste0("master_", state, ".parquet"))
  lock <- jsonlite::read_json(source_lock)
  hash <- digest::digest(file = path, algo = "sha256")
  if (!identical(hash, lock$sha256[[state]])) {
    stop("Source hash changed for ", state, "; review docs/source_lock.json")
  }
  list(
    seats = arrow::read_parquet(path) |> tibble::as_tibble(),
    provenance = tibble::tibble(
      state = state, path = normalizePath(path), sha256 = hash,
      pinned_commit = lock$source_commit,
      current_commit = system2("git", c("-C", shQuote(source_root), "rev-parse", "HEAD"), stdout = TRUE)
    )
  )
}

write_build <- function(object, directory, name) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  saveRDS(object, file.path(directory, paste0(name, ".rds")))
}
