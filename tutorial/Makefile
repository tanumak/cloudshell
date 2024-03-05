LIGHTTPD_PORT := 40000
IMAGE_PATH := $(shell readlink -f images)

TEMPLATE_DIR := template
OUTPUT_DIR := .

TEMPLATE_MD := $(wildcard $(TEMPLATE_DIR)/*.md)
TUTORIAL_MD := $(patsubst $(TEMPLATE_DIR)/%.md, $(OUTPUT_DIR)/%.md, $(notdir $(TEMPLATE_MD)))

all: lighttpd $(TUTORIAL_MD)

lighttpd: lighttpd-install lighttpd-conf lighttpd-start

lighttpd-install:
ifeq ($(wildcard /usr/sbin/lighttpd),)
	@sudo apt install -y lighttpd >/dev/null 2>&1
endif

lighttpd-conf:
	@sed -e "s#\$$IMAGE_PATH#$(IMAGE_PATH)#g; s/\$$LIGHTTPD_PORT/$(LIGHTTPD_PORT)/g" template/lighttpd.conf > lighttpd.conf

lighttpd-start:
	@if ps -ef | grep lighttpd | grep -v grep >/dev/null; then pkill lighttpd; fi
	@lighttpd -f lighttpd.conf

$(OUTPUT_DIR)/%.md: $(TEMPLATE_DIR)/%.md
	@sed -e "s/\$$WEB_HOST/$(WEB_HOST)/g; s/\$$LIGHTTPD_PORT/$(LIGHTTPD_PORT)/g" $< > $@

clean:
	@rm -f $(TUTORIAL_MD) lighttpd.conf
	@if ps -ef | grep lighttpd | grep -v grep >/dev/null; then pkill lighttpd; fi
	@sudo apt remove -y lighttpd >/dev/null 2>&1
