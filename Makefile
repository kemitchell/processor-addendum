CFCM=node_modules/.bin/commonform-commonmark
CFDOCX=node_modules/.bin/commonform-docx
CRITIQUE=node_modules/.bin/commonform-critique
JSON=node_modules/.bin/json
LINT=node_modules/.bin/commonform-lint
TOOLS=$(CFCM) $(CFDOCX) $(CRITIQUE) $(JSON) $(LINT)

BUILD=build
BASENAMES=addendum
FORMS=$(addsuffix .form.json,$(addprefix $(BUILD)/,$(BASENAMES)))

GIT_TAG=$(shell (git diff-index --quiet HEAD && git describe --exact-match --tags 2>/dev/null | sed 's/v//'))
EDITION:=$(or $(EDITION),$(if $(GIT_TAG),$(GIT_TAG),Internal Draft))
EDITION_FLAG=--edition "$(EDITION)"

all: docx pdf md

docx: $(addprefix $(BUILD)/,$(BASENAMES:=.docx))
pdf: $(addprefix $(BUILD)/,$(BASENAMES:=.pdf))
md: $(addprefix $(BUILD)/,$(BASENAMES:=.md))

$(BUILD)/%.docx: $(BUILD)/%.form.json $(BUILD)/%.title $(BUILD)/%.directions blanks.json $(BUILD)/%.signatures styles.json | $(CFDOCX) $(BUILD)
	$(CFDOCX) --title "$(shell cat $(BUILD)/$*.title)" --edition "$(EDITION)" --number outline --indent-margins --left-align-title --directions $(BUILD)/$*.directions --values blanks.json --styles styles.json --signatures $(BUILD)/$*.signatures $< > $@

$(BUILD)/%.md: $(BUILD)/%.form.json $(BUILD)/%.title $(BUILD)/%.directions blanks.json | $(CFCM) $(BUILD)
	$(CFCM) stringify --title "$(shell cat $(BUILD)/$*.title)" --edition "$(EDITION)" --directions $(BUILD)/$*.directions --values blanks.json --ordered --ids < $< >> $@

$(BUILD)/%.form.json: %.md | $(BUILD) $(CFCM)
	$(CFCM) parse --only form < $< > $@

$(BUILD)/%.title: %.md | $(BUILD) $(CFCM) $(JSON)
	$(CFCM) parse < $< | $(JSON) frontMatter.title > $@

$(BUILD)/%.directions: %.md | $(BUILD) $(CFCM)
	$(CFCM) parse --only directions < $< > $@

$(BUILD)/%.signatures: %.md | $(BUILD) $(CFCM) $(JSON)
	$(CFCM) parse < $< | $(JSON) frontMatter.signaturePages > $@

%.pdf: %.docx
	unoconv $<

$(BUILD):
	mkdir -p $@

$(TOOLS):
	npm ci

.PHONY: clean docker lint critique

lint: $(FORMS) | $(LINT) $(JSON)
	@for form in $(FORMS); do \
		echo ; \
		echo $$form; \
		cat $$form | $(LINT) | $(JSON) -a message | sort -u; \
	done; \

critique: $(FORMS) | $(CRITIQUE) $(JSON)
	@for form in $(FORMS); do \
		echo ; \
		echo $$form ; \
		cat $$form | $(CRITIQUE) | $(JSON) -a message | sort -u; \
	done

clean:
	rm -rf $(BUILD)

docker:
	docker build -t processor-addendum .
	docker run --name processor-addendum processor-addendum
	docker cp processor-addendum:/workdir/$(BUILD) .
	docker rm processor-addendum
