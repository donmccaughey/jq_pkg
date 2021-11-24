APP_SIGNING_ID ?= Developer ID Application: Donald McCaughey
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
	test "$(shell lipo -archs $(TMP)/jq/install/usr/local/bin/jq)" = "x86_64 arm64"
	test "$(shell lipo -archs $(TMP)/jq/install/usr/local/lib/libjq.a)" = "x86_64 arm64"
	codesign --verify --strict $(TMP)/jq/install/usr/local/bin/jq
	codesign --verify --strict $(TMP)/jq/install/usr/local/lib/libjq.a


.PHONY : onig
onig : $(TMP)/onig/install/usr/local/lib/libonig.a


.PHONY : jq
jq : $(TMP)/jq.pkg



##### compilation flags ##########

arch_flags = $(patsubst %,-arch %,$(archs))

CFLAGS += $(arch_flags)


##### tmp ##########

$(TMP) :
	mkdir -p $@


##### oniguruma ##########

onig_configure_options := \
		--disable-silent-rules \
		--enable-shared=no \
		CFLAGS='$(CFLAGS)'

onig_sources := $(shell find onig -type f \! -name .DS_Store)

$(TMP)/onig/install/usr/local/include/oniggnu.h \
$(TMP)/onig/install/usr/local/include/oniguruma.h \
$(TMP)/onig/install/usr/local/lib/libonig.a : $(TMP)/onig-installed.stamp.txt
	@:

$(TMP)/onig-installed.stamp.txt : $(TMP)/onig/build/src/.libs/libonig.a | $(TMP)/onig/install
	cd $(TMP)/onig/build && $(MAKE) DESTDIR=$(TMP)/onig/install install
	date > $@

$(TMP)/onig/build/src/.libs/libonig.a : $(TMP)/onig/build/config.status $(onig_sources)
	cd $(TMP)/onig/build && $(MAKE)

$(TMP)/onig/build/config.status : onig/configure | $$(dir $$@)
	cd $(TMP)/onig/build && sh $(abspath $<) $(onig_configure_options)

$(TMP)/onig/build \
$(TMP)/onig/install :
	mkdir -p $@


##### jq ##########

jq_configure_options := \
		--disable-silent-rules \
		--disable-maintainer-mode \
		--enable-shared=no \
		--enable-all-static \
		--with-oniguruma=$(TMP)/onig/install/usr/local \
		CFLAGS='$(CFLAGS) -Wno-implicit-function-declaration'

jq_sources := $(shell find jq -type f \! -name .DS_Store)

$(TMP)/jq/install/usr/local/bin/jq \
$(TMP)/jq/install/usr/local/include/jq.h \
$(TMP)/jq/install/usr/local/lib/libjq.a \
$(TMP)/jq/install/usr/local/share/man/man1/jq.1: $(TMP)/jq-installed.stamp.txt
	@:

$(TMP)/jq-installed.stamp.txt : $(TMP)/jq/build/src/jq | $(TMP)/jq/install
	cd $(TMP)/jq/build && $(MAKE) DESTDIR=$(TMP)/jq/install install
	date > $@

$(TMP)/jq/build/src/jq : $(TMP)/jq/build/config.status $(jq_sources)
	cd $(TMP)/jq/build && $(MAKE)

$(TMP)/jq/build/config.status : \
				jq/configure \
				$(TMP)/onig/install/usr/local/include/oniggnu.h \
				$(TMP)/onig/install/usr/local/include/oniguruma.h \
				$(TMP)/onig/install/usr/local/lib/libonig.a \
				| $$(dir $$@)
	cd $(TMP)/jq/build && sh $(abspath $<) $(jq_configure_options)

$(TMP)/jq/build \
$(TMP)/jq/install :
	mkdir -p $@


##### pkg ##########

$(TMP)/jq-signed.stamp.txt : $(TMP)/jq/install/usr/local/bin/jq | $$(dir $$@)
	xcrun codesign --sign "$(APP_SIGNING_ID)" --options runtime  $<
	date > $@

$(TMP)/libjq.a-signed.stamp.txt : $(TMP)/jq/install/usr/local/lib/libjq.a | $$(dir $$@)
	xcrun codesign --sign "$(APP_SIGNING_ID)" --options runtime  $<
	date > $@

$(TMP)/jq.pkg : \
		$(TMP)/jq-signed.stamp.txt \
		$(TMP)/libjq.a-signed.stamp.txt \
		$(TMP)/jq/install/usr/local/include/jq.h \
		$(TMP)/jq/install/usr/local/share/man/man1/jq.1
	pkgbuild \
		--root $(TMP)/jq/install \
		--identifier cc.donm.pkg.jq \
		--ownership recommended \
		--version $(version) \
		$@

