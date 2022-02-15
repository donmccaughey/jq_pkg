APP_SIGNING_ID ?= Developer ID Application: Donald McCaughey
INSTALLER_SIGNING_ID ?= Developer ID Installer: Donald McCaughey
NOTARIZATION_KEYCHAIN_PROFILE ?= Donald McCaughey
TMP ?= $(abspath tmp)

version := 1.6
oniguruma_version := 6.9.7.1
revision := 1
archs := arm64 x86_64

rev := $(if $(patsubst 1,,$(revision)),-r$(revision),)
ver := $(version)$(rev)


.SECONDEXPANSION :


.PHONY : signed-package
signed-package: jq-$(ver).pkg


.PHONY : notarize
notarize : $(TMP)/stapled.stamp.txt


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
	pkgutil --check-signature jq-$(ver).pkg
	pkgutil --check-signature jq-$(ver).pkg
	spctl --assess --type install jq-$(ver).pkg
	xcrun stapler validate jq-$(ver).pkg


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

$(TMP)/jq-installed.stamp.txt : $(TMP)/jq/build/jq | $(TMP)/jq/install
	cd $(TMP)/jq/build && $(MAKE) DESTDIR=$(TMP)/jq/install install
	date > $@

$(TMP)/jq/build/jq : $(TMP)/jq/build/config.status $(jq_sources)
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
		$(TMP)/jq/install/etc/manpaths.d/jq.manpath \
		$(TMP)/jq/install/etc/paths.d/jq.path \
		$(TMP)/jq/install/usr/local/bin/jq \
		$(TMP)/jq/install/usr/local/include/jq.h \
		$(TMP)/jq/install/usr/local/lib/libjq.a \
		$(TMP)/jq/install/usr/local/share/man/man1/jq.1 \
		$(TMP)/jq/install/usr/local/bin/uninstall-jq \
		$(TMP)/jq/install/usr/local/include/jq.h \
		$(TMP)/jq/install/usr/local/share/man/man1/jq.1 \
		$(TMP)/jq-signed.stamp.txt \
		$(TMP)/libjq.a-signed.stamp.txt
	pkgbuild \
		--root $(TMP)/jq/install \
		--identifier cc.donm.pkg.jq \
		--ownership recommended \
		--version $(version) \
		$@

$(TMP)/jq/install/etc/manpaths.d/jq.manpath : jq.manpath | $$(dir $$@)
	cp $< $@

$(TMP)/jq/install/etc/paths.d/jq.path : jq.path | $$(dir $$@)
	cp $< $@

$(TMP)/jq/install/usr/local/bin/uninstall-jq : \
		uninstall-jq \
		$(TMP)/jq/install/etc/manpaths.d/jq.manpath \
		$(TMP)/jq/install/etc/paths.d/jq.path \
		$(TMP)/jq/install/usr/local/bin/jq \
		$(TMP)/jq/install/usr/local/include/jq.h \
		$(TMP)/jq/install/usr/local/lib/libjq.a \
		$(TMP)/jq/install/usr/local/share/man/man1/jq.1 \
		| $$(dir $$@)
	cp $< $@
	cd $(TMP)/jq/install && find . -type f \! -name .DS_Store | sort >> $@
	sed -e 's/^\./rm -f /g' -i '' $@
	chmod a+x $@

$(TMP) \
$(TMP)/jq/install/etc/manpaths.d \
$(TMP)/jq/install/etc/paths.d :
	mkdir -p $@


##### product ##########

arch_list := $(shell printf '%s' '$(archs)' | sed 's/ / and /g')
date := $(shell date '+%Y-%m-%d')
macos := $(shell \
	system_profiler -detailLevel mini SPSoftwareDataType \
	| grep 'System Version:' \
	| awk -F ' ' '{print $$4}' \
	)
xcode := $(shell \
	system_profiler -detailLevel mini SPDeveloperToolsDataType \
	| grep 'Version:' \
	| awk -F ' ' '{print $$2}' \
	)

jq-$(ver).pkg : \
		$(TMP)/jq.pkg \
		$(TMP)/build-report.txt \
		$(TMP)/distribution.xml \
		$(TMP)/resources/background.png \
		$(TMP)/resources/background-darkAqua.png \
		$(TMP)/resources/licenses.html \
		$(TMP)/resources/welcome.html
	productbuild \
		--distribution $(TMP)/distribution.xml \
		--resources $(TMP)/resources \
		--package-path $(TMP) \
		--version v$(version)-r$(revision) \
		--sign '$(INSTALLER_SIGNING_ID)' \
		$@

$(TMP)/build-report.txt : | $$(dir $$@)
	printf 'Build Date: %s\n' "$(date)" > $@
	printf 'Software Version: %s\n' "$(version)" >> $@
	printf 'Oniguruma Version: %s\n' "$(oniguruma_version)" >> $@
	printf 'Installer Revision: %s\n' "$(revision)" >> $@
	printf 'Architectures: %s\n' "$(arch_list)" >> $@
	printf 'macOS Version: %s\n' "$(macos)" >> $@
	printf 'Xcode Version: %s\n' "$(xcode)" >> $@
	printf 'Tag Version: v%s-r%s\n' "$(version)" "$(revision)" >> $@
	printf 'APP_SIGNING_ID: %s\n' "$(APP_SIGNING_ID)" >> $@
	printf 'INSTALLER_SIGNING_ID: %s\n' "$(INSTALLER_SIGNING_ID)" >> $@
	printf 'NOTARIZATION_KEYCHAIN_PROFILE: %s\n' "$(NOTARIZATION_KEYCHAIN_PROFILE)" >> $@
	printf 'TMP directory: %s\n' "$(TMP)" >> $@
	printf 'CFLAGS: %s\n' "$(CFLAGS)" >> $@
	printf 'Release Title: jq %s for macOS rev %s\n' "$(version)" "$(revision)" >> $@
	printf 'Description: A signed macOS installer package for `jq` %s.\n' "$(version)" >> $@

$(TMP)/distribution.xml \
$(TMP)/resources/welcome.html : $(TMP)/% : % | $$(dir $$@)
	sed \
		-e 's/{{arch_list}}/$(arch_list)/g' \
		-e 's/{{date}}/$(date)/g' \
		-e 's/{{macos}}/$(macos)/g' \
		-e 's/{{oniguruma_version}}/$(oniguruma_version)/g' \
		-e 's/{{revision}}/$(revision)/g' \
		-e 's/{{version}}/$(version)/g' \
		-e 's/{{xcode}}/$(xcode)/g' \
		$< > $@

$(TMP)/resources/background.png \
$(TMP)/resources/background-darkAqua.png \
$(TMP)/resources/licenses.html : $(TMP)/% : % | $(TMP)/resources
	cp $< $@

$(TMP)/resources :
	mkdir -p $@


##### notarization ##########

$(TMP)/submit-log.json : jq-$(ver).pkg | $$(dir $$@)
	xcrun notarytool submit $< \
		--keychain-profile "$(NOTARIZATION_KEYCHAIN_PROFILE)" \
		--output-format json \
		--wait \
		> $@

$(TMP)/submission-id.txt : $(TMP)/submit-log.json | $$(dir $$@)
	jq --raw-output '.id' < $< > $@

$(TMP)/notarization-log.json : $(TMP)/submission-id.txt | $$(dir $$@)
	xcrun notarytool log "$$(<$<)" \
		--keychain-profile "$(NOTARIZATION_KEYCHAIN_PROFILE)" \
		$@

$(TMP)/notarized.stamp.txt : $(TMP)/notarization-log.json | $$(dir $$@)
	test "$$(jq --raw-output '.status' < $<)" = "Accepted"
	date > $@

$(TMP)/stapled.stamp.txt : jq-$(ver).pkg $(TMP)/notarized.stamp.txt
	xcrun stapler staple $<
	date > $@

