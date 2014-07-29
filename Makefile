# include ../common.make
# SELFDIR := $(SRCROOT)/openssl
BUILDDIR := build
SELFDIR := $(shell pwd)

ifeq ($(PLATFORM),ios)
	LIBDIR := $(SELFDIR)/lib-ios
	INCDIR := $(SELFDIR)/include-ios
else
	LIBDIR := $(SELFDIR)/lib-osx
	INCDIR := $(SELFDIR)/include-osx
endif

all: pre 
all: "$(BUILDDIR)/lib/libssl.a"
all: "$(BUILDDIR)/lib/libcrypto.a"
all: "$(BUILDDIR)/lib/libevent.a"
all: "$(BUILDDIR)/lib/libevent_core.a"
all: "$(BUILDDIR)/lib/libevent_extra.a"
all: "$(BUILDDIR)/lib/libevent_openssl.a"
all: "$(BUILDDIR)/lib/libleveldb.a"
all: "$(BUILDDIR)/include/openssl"
all: "$(BUILDDIR)/include/event2"
all: "$(BUILDDIR)/include/leveldb"
pre:
	mkdir -p "$(BUILDDIR)/lib" "$(BUILDDIR)/include"

"$(BUILDDIR)/lib/libssl.a":
	ln -fs "$(LIBDIR)/libssl.a" "$(BUILDDIR)/lib/libssl.a"
"$(BUILDDIR)/lib/libcrypto.a":
	ln -fs "$(LIBDIR)/libcrypto.a" "$(BUILDDIR)/lib/libcrypto.a"
"$(BUILDDIR)/lib/libevent.a":
	ln -fs "$(LIBDIR)/libevent.a" "$(BUILDDIR)/lib/libevent.a"
"$(BUILDDIR)/lib/libevent_core.a":
	ln -fs "$(LIBDIR)/libevent_core.a" "$(BUILDDIR)/lib/libevent_core.a"
"$(BUILDDIR)/lib/libevent_extra.a":
	ln -fs "$(LIBDIR)/libevent_extra.a" "$(BUILDDIR)/lib/libevent_extra.a"
"$(BUILDDIR)/lib/libevent_openssl.a":
	ln -fs "$(LIBDIR)/libevent_openssl.a" "$(BUILDDIR)/lib/libevent_openssl.a"
"$(BUILDDIR)/lib/libleveldb.a":
	ln -fs "$(LIBDIR)/libleveldb.a" "$(BUILDDIR)/lib/libleveldb.a"

"$(BUILDDIR)/include/openssl":
	rm -rf "$(BUILDDIR)/include/openssl"
	ln -fs "$(SELFDIR)/include/openssl" "$(BUILDDIR)/include/openssl"

"$(BUILDDIR)/include/event2":
	rm -rf "$(BUILDDIR)/include/event2"
	ln -fs "$(SELFDIR)/include/event2" "$(BUILDDIR)/include/event2"

"$(BUILDDIR)/include/leveldb":
	rm -rf "$(BUILDDIR)/include/leveldb"
	ln -fs "$(SELFDIR)/include/leveldb" "$(BUILDDIR)/include/leveldb"

clean:
	rm -rf "$(BUILDDIR)/include/openssl" \
	       "$(BUILDDIR)/include/event2" \
	       "$(BUILDDIR)/include/leveldb" \
	       "$(BUILDDIR)/lib/libssl.a" \
	       "$(BUILDDIR)/lib/libcrypto.a" \
	       "$(BUILDDIR)/lib/libevent.a" \
	       "$(BUILDDIR)/lib/libevent_core.a" \
	       "$(BUILDDIR)/lib/libevent_extra.a" \
	       "$(BUILDDIR)/lib/libevent_openssl.a" \
	       "$(BUILDDIR)/lib/libleveldb.a"

rebuild:
	rm -rf lib-* include-* .build*
	./build-openssl.sh
	./build-libevent.sh
	./build-leveldb.sh

.PHONY: all pre clean rebuild
