# Instalação para todo o sistema, usada pelos pacotes (.deb, Arch...).
# Para instalar só para o seu usuário, sem sudo, use ./install.sh.
#
#   sudo make install                      instala em /usr/local
#   make install PREFIX=/usr DESTDIR=pkg   monta a árvore de um pacote
#   sudo make uninstall

PREFIX ?= /usr/local
SYSCONFDIR ?= /etc
DESTDIR ?=

APP = io.github.hendesson.constancia
EXT = constancia@hendesson.github.io
BINDIR = $(DESTDIR)$(PREFIX)/bin
UNITDIR = $(DESTDIR)$(PREFIX)/lib/systemd/user
APPDIR = $(DESTDIR)$(PREFIX)/share/applications
AUTOSTARTDIR = $(DESTDIR)$(SYSCONFDIR)/xdg/autostart
EXTDIR = $(DESTDIR)$(PREFIX)/share/gnome-shell/extensions/$(EXT)
ICONDIR = $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps
DOCDIR = $(DESTDIR)$(PREFIX)/share/doc/constancia

.PHONY: install uninstall

install:
	install -Dm755 constancia $(BINDIR)/constancia
	install -Dm644 systemd/constancia.timer $(UNITDIR)/constancia.timer
	sed 's|%h/.local/bin/constancia|$(PREFIX)/bin/constancia|' systemd/constancia.service > $(UNITDIR)/constancia.service
	chmod 644 $(UNITDIR)/constancia.service
	install -Dm644 data/$(APP).desktop $(APPDIR)/$(APP).desktop
	install -Dm644 data/$(APP).desktop $(AUTOSTARTDIR)/$(APP).desktop
	install -Dm644 data/$(APP).svg $(ICONDIR)/$(APP).svg
	install -Dm644 gnome-extension/$(EXT)/metadata.json $(EXTDIR)/metadata.json
	install -Dm644 gnome-extension/$(EXT)/extension.js $(EXTDIR)/extension.js
	install -Dm644 gnome-extension/$(EXT)/constancia-symbolic.svg $(EXTDIR)/constancia-symbolic.svg
	install -Dm644 README.md $(DOCDIR)/README.md
	install -Dm644 LICENSE $(DOCDIR)/LICENSE

uninstall:
	rm -f $(BINDIR)/constancia $(UNITDIR)/constancia.timer $(UNITDIR)/constancia.service
	rm -f $(APPDIR)/$(APP).desktop $(AUTOSTARTDIR)/$(APP).desktop $(ICONDIR)/$(APP).svg
	rm -rf $(EXTDIR) $(DOCDIR)
