.PHONY: all build install clean deb rpm arch

PREFIX ?= /usr/local
DESTDIR ?=
BINDIR = $(DESTDIR)$(PREFIX)/bin

all: build

build:
	cargo build --release

install: build
	install -Dm755 target/release/zsh-mgr $(BINDIR)/zsh-mgr

clean:
	cargo clean

# Debian/Ubuntu package
deb: build
	cargo install cargo-deb
	cargo deb

# RPM package (Fedora, RHEL, etc.)
rpm: build
	cargo install cargo-generate-rpm
	cargo generate-rpm

# Arch Linux PKGBUILD
arch:
	@echo "Build PKGBUILD for Arch Linux"
	@echo "See PKGBUILD file"
