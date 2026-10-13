#!/bin/sh
# Gera dist/constancia_VERSAO_all.deb (Debian, Ubuntu, Mint, Pop!_OS...).
# Precisa de: make, dpkg-deb, fakeroot.
set -e
cd "$(dirname "$0")/.."

VERSAO=$(./constancia --version | cut -d' ' -f2)
RAIZ=$(mktemp -d)
trap 'rm -rf "$RAIZ"' EXIT

make install PREFIX=/usr DESTDIR="$RAIZ" >/dev/null
mkdir -p "$RAIZ/DEBIAN"
cat > "$RAIZ/DEBIAN/control" <<FIM
Package: constancia
Version: $VERSAO
Architecture: all
Maintainer: Hendesson <137210602+Hendesson@users.noreply.github.com>
Section: utils
Priority: optional
Homepage: https://github.com/Hendesson/constancia
Depends: python3 (>= 3.8), python3-gi, python3-gi-cairo, gir1.2-gtk-4.0 (>= 4.6)
Recommends: git, sound-theme-freedesktop, pipewire-bin | pulseaudio-utils
Description: painel com clima, tarefas e gráfico de atividade
 Painel para a área de trabalho que abre ao entrar na sessão e mostra o
 clima, as tarefas e um gráfico no estilo "contribution graph": usar o
 computador conta, e cada tarefa concluída conta mais.
FIM

mkdir -p dist
fakeroot dpkg-deb --build "$RAIZ" "dist/constancia_${VERSAO}_all.deb" >/dev/null
echo "dist/constancia_${VERSAO}_all.deb"
