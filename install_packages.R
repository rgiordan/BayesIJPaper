#!/usr/bin/env Rscript
#
# Read r_packages.csv, install any missing CRAN packages, and print
# the installed version of every package listed.

repo_root <- system("git rev-parse --show-toplevel", intern=TRUE)
pkg_csv   <- file.path(repo_root, "r_packages.csv")

pkgs <- read.csv(pkg_csv, stringsAsFactors=FALSE)$package

cat("Checking", length(pkgs), "packages...\n\n")

missing_pkgs <- pkgs[!sapply(pkgs, requireNamespace, quietly=TRUE)]

if (length(missing_pkgs) > 0) {
  cat("Installing missing packages:\n")
  cat(paste(" ", missing_pkgs, collapse="\n"), "\n\n")
  install.packages(missing_pkgs, repos="https://cloud.r-project.org")
} else {
  cat("All packages already installed.\n\n")
}

cat(sprintf("%-20s %s\n", "Package", "Version"))
cat(strrep("-", 35), "\n")
for (pkg in sort(pkgs)) {
  ver <- tryCatch(
    as.character(packageVersion(pkg)),
    error=function(e) "NOT INSTALLED"
  )
  cat(sprintf("%-20s %s\n", pkg, ver))
}
