TMP ?= $(abspath tmp)

version := 1.6
oniguruma_version := 6.9.7.1
revision := 1
archs := arm64 x86_64


.SECONDEXPANSION :


.PHONY : signed-package
signed-package: jq-$(version).pkg


.PHONY : clean
clean :
	-rm -f jq-*.pkg
	-rm -rf $(TMP)


.PHONY : check
check :
	test "$(shell lipo -archs $(TMP)/onig/install/usr/local/lib/libonig.a)" = "x86_64 arm64"
#	test "$(shell lipo -archs $(TMP)/jq/install/usr/local/bin/jq)" = "x86_64 arm64"


.PHONY : onig
onig : $(TMP)/onig/install/usr/local/lib/libonig.a


.PHONY : jq
jq : $(TMP)/jq/install/usr/local/bin/jq



##### compilation flags ##########

arch_flags = $(patsubst %,-arch %,$(archs))

CFLAGS += $(arch_flags)


##### oniguruma ##########

onig_configure_options := \
		--disable-silent-rules \
		--enable-shared=no \
		CFLAGS='$(CFLAGS)'

onig_sources := $(shell find onig -type f \! -name .DS_Store)

$(TMP)/onig/install/usr/local/include/oniggnu.h \
$(TMP)/onig/install/usr/local/include/oniguruma.h \
$(TMP)/onig/install/usr/local/lib/libonig.a : $(TMP)/onig/installed.stamp.txt
	@:

$(TMP)/onig/installed.stamp.txt : $(TMP)/onig/build/src/.libs/libonig.a | $(TMP)/onig/install
	cd $(TMP)/onig/build && $(MAKE) DESTDIR=$(TMP)/onig/install install
	date > $@

$(TMP)/onig/build/src/.libs/libonig.a : $(TMP)/onig/build/config.status $(onig_sources)
	cd $(TMP)/onig/build && $(MAKE)

$(TMP)/onig/build/config.status : onig/configure | $$(dir $$@)
	cd $(TMP)/onig/build && sh $(abspath onig/configure) $(onig_configure_options)

$(TMP)/onig/build \
$(TMP)/onig/install :
	mkdir -p $@

