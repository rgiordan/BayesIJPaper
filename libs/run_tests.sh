#!/usr/bin/env bash
# Run the testthat tests for all libraries.
# Must be run from any directory within the git repo.

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
LIBS="$REPO_ROOT/libs"

run_tests() {
    local pkg_dir="$1"
    local pkg_name="$2"
    echo "========================================"
    echo "Testing $pkg_name"
    echo "========================================"
    Rscript -e "
        library(devtools)
        devtools::load_all('$pkg_dir', quiet=TRUE)
        devtools::test('$pkg_dir')
    "
}

run_tests "$LIBS/bayesijlib/bayesijlib"   "bayesijlib"
run_tests "$LIBS/bayesijmrp/bayesijmrp"   "bayesijmrp"
run_tests "$LIBS/rstanarmijlib/rstanarmijlib" "rstanarmijlib"
run_tests "$LIBS/rstanijlib/rstanijlib"   "rstanijlib"
run_tests "$LIBS/bayesijpaper/bayesijpaper" "bayesijpaper"

echo "========================================"
echo "All tests complete."
echo "========================================"
