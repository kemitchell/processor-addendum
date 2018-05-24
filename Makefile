COMMONFORM=node_modules/.bin/commonform
FORMS=$(basename $(wildcard *.cform))

all: $(FORMS:=.docx) $(FORMS:=.pdf) $(FORMS:=.md) $(FORMS:=.cform.json)

%.docx: %.cform %.json %.options blanks.json styles.json | $(COMMONFORM)
	$(COMMONFORM) render -f docx $(shell cat $*.options) --blanks blanks.json --signatures $*.json --left-align-title --indent-margins --styles styles.json $< > $@

%.md: %.cform %.options blanks.json | $(COMMONFORM)
	$(COMMONFORM) render -f markdown $(shell cat $*.options) --blanks blanks.json --ordered-lists $< > $@

%.cform.json: %.cform | $(COMMONFORM)
	$(COMMONFORM) render -f native $< > $@

%.pdf: %.docx
	unoconv $<

$(COMMONFORM):
	npm install
