SHELL = /bin/bash

GIT_REPO_LOC := $(shell git rev-parse --show-toplevel)
PAPER_LOC := $(GIT_REPO_LOC)/paper/latex


#####################################
# Knitr and latex

.PHONY recompile_knitr:
	Rscript -e 'library(knitr); knit("figures_knitr.Rnw")'
	latexmk figures.tex

figures_knitr.tex:
	Rscript -e 'library(knitr); knit("figures_knitr.Rnw")'

figures.pdf: figures_knitr.tex
	latexmk figures.tex

clean_latex:
	for FILE in $$(ls figures.*); do \
		if [ $$FILE != figures.tex ]; then echo "Deleting "$$FILE; rm $$FILE; fi \
	done
	rm *.fdb_latexmk
	rm *.fls
	rm *.log
	rm *.aux

