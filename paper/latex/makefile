SHELL = /bin/bash

GIT_REPO_LOC := $(shell git rev-parse --show-toplevel)
PAPER_LOC=${GIT_REPO_LOC}/paper/latex


#####################################
# Knitr and latex

.PHONY recompile_knitr:
	Rscript -e 'library(knitr); knit("figures_knitr.Rnw")'
	latexmk figures.tex

figures_knitr.tex:
	Rscript -e 'library(knitr); knit("figures_knitr.Rnw")'

main.pdf: figures_knitr.tex
    # Call twice to handle the cross references
	latexmk main.tex
	latexmk supplement.tex
	latexmk -g main.tex
	latexmk -g supplement.tex

supplement.pdf:
    # Call twice to handle the cross references
	latexmk main.tex
	latexmk supplement.tex
	latexmk -g main.tex
	latexmk -g supplement.tex

# Copy only the latex to a subfolder for uploading to the arxiv.
# Note to set the etoolbox boolean arxiv to true before doing this.
arxiv: main.pdf
	cp *.tex arxiv/
	cp -R appendices arxiv/
	cp -R figure arxiv/
	cp -R simple_examples arxiv/

	cp *.bib arxiv/
	cp *.bbl arxiv/
	cp *.blg arxiv/

	cp main.bbl arxiv/references.bbl # To fool arxiv

	echo 'Now run cd arxiv; tar -czvf ./arxiv.tgz *; cd ..'

clean_figures:
	rm figure/*
	rm figures_knitr.tex

clean_latex:
	for FILE in $$(ls main.*); do \
		if [ $$FILE != main.tex ]; then echo "Deleting "$$FILE; rm $$FILE; fi \
	done
	for FILE in $$(ls supplement.*); do \
		if [ $$FILE != supplement.tex ]; then echo "Deleting "$$FILE; rm $$FILE; fi \
	done
