include ../common.make
SELFDIR := $(SRCROOT)/openssl
# BUILDDIR := build
# SELFDIR := $(pwd)

ifeq ($(PLATFORM),ios)
	libssl_a    := $(SELFDIR)/lib/libssl-ios.a
	libcrypto_a := $(SELFDIR)/lib/libcrypto-ios.a
else
	libssl_a    := $(SELFDIR)/lib/libssl-osx.a
	libcrypto_a := $(SELFDIR)/lib/libcrypto-osx.a
endif

openssl: opensslpre "$(BUILDDIR)/lib/libssl.a" "$(BUILDDIR)/lib/libcrypto.a" "$(BUILDDIR)/include/openssl"
opensslpre:
	mkdir -p "$(BUILDDIR)/lib" "$(BUILDDIR)/include"

"$(BUILDDIR)/lib/libssl.a": $(libssl_a)
	ln -fs "$(libssl_a)" "$(BUILDDIR)/lib/libssl.a"

"$(BUILDDIR)/lib/libcrypto.a":
	ln -fs $(libcrypto_a) "$(BUILDDIR)/lib/libcrypto.a"

"$(BUILDDIR)/include/openssl":
	rm -rf "$(BUILDDIR)/include/openssl"
	ln -fs "$(SELFDIR)/include/openssl" "$(BUILDDIR)/include/openssl"

$(libssl_a):
	./build.sh

clean:
	rm -rf "$(BUILDDIR)/include/openssl" "$(BUILDDIR)/lib/libssl.a" "$(BUILDDIR)/lib/libcrypto.a"

deepclean:
	rm -rf "$(SELFDIR)/lib" "$(SELFDIR)/include"

rebuild: deepclean
	./build.sh

.PHONY: opensslpre clean deepclean rebuild
