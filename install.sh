#!/bin/sh
# Instala o constancia para o usuário atual (não precisa de sudo).
set -e
cd "$(dirname "$0")"

install -Dm755 constancia "$HOME/.local/bin/constancia"
echo "✔ instalado em ~/.local/bin/constancia"

if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  install -Dm644 systemd/constancia.service "$HOME/.config/systemd/user/constancia.service"
  install -Dm644 systemd/constancia.timer "$HOME/.config/systemd/user/constancia.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now constancia.timer >/dev/null 2>&1
  echo "✔ timer ativado: os dias de uso são registrados sozinhos"
else
  echo "! systemd de usuário não encontrado: os dias de uso só serão"
  echo "  registrados enquanto o painel estiver aberto"
fi

# O painel precisa de Python com GTK 4.6+ e da ponte com o cairo (para desenhar o gráfico)
tem_gtk() {
  python3 -c '
import gi
gi.require_version("Gtk", "4.0")
gi.require_foreign("cairo")
from gi.repository import Gtk
assert (Gtk.get_major_version(), Gtk.get_minor_version()) >= (4, 6)
' >/dev/null 2>&1
}

como_instalar_gtk() {
  [ -r /etc/os-release ] && . /etc/os-release
  case " $ID $ID_LIKE " in
    *" debian "*|*" ubuntu "*) echo "sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-4.0" ;;
    *" fedora "*|*" rhel "*)   echo "sudo dnf install python3-gobject gtk4" ;;
    *" arch "*)                echo "sudo pacman -S python-gobject python-cairo gtk4" ;;
    *" suse "*|*" opensuse "*) echo "sudo zypper install python3-gobject python3-gobject-cairo typelib-1_0-Gtk-4_0" ;;
    *) echo "instale o PyGObject (com cairo) e o GTK 4 pelo gerenciador de pacotes da sua distro" ;;
  esac
}

if tem_gtk; then
  # O arquivo leva o id do aplicativo para o sistema associar janela, ícone e notificações
  ATALHO=io.github.hendesson.constancia.desktop
  mkdir -p "$HOME/.local/share/applications" "$HOME/.config/autostart"
  rm -f "$HOME/.local/share/applications/constancia.desktop" "$HOME/.config/autostart/constancia.desktop"
  cat > "$HOME/.local/share/applications/$ATALHO" <<FIM
[Desktop Entry]
Type=Application
Name=Constância
Comment=Clima, tarefas e gráfico de atividade
Exec=$HOME/.local/bin/constancia painel
Icon=io.github.hendesson.constancia
Categories=Utility;
FIM
  cp "$HOME/.local/share/applications/$ATALHO" "$HOME/.config/autostart/$ATALHO"
  install -Dm644 data/io.github.hendesson.constancia.svg \
    "$HOME/.local/share/icons/hicolor/scalable/apps/io.github.hendesson.constancia.svg"
  echo "✔ painel no menu de aplicativos e abrindo sozinho ao entrar na sessão"
else
  echo "! GTK 4.6+ para Python não encontrado: o painel não vai abrir. Instale com:"
  echo "    $(como_instalar_gtk)"
  echo "  e rode ./install.sh de novo."
fi

# Extensão opcional do GNOME: prende o painel à área de trabalho
EXT=constancia@hendesson.github.io
if command -v gnome-extensions >/dev/null 2>&1 && command -v gsettings >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/share/gnome-shell/extensions"
  rm -rf "$HOME/.local/share/gnome-shell/extensions/$EXT"
  cp -r "gnome-extension/$EXT" "$HOME/.local/share/gnome-shell/extensions/"
  ativas=$(gsettings get org.gnome.shell enabled-extensions)
  case "$ativas" in
    *"$EXT"*) ;;
    "@as []") gsettings set org.gnome.shell enabled-extensions "['$EXT']" ;;
    *) gsettings set org.gnome.shell enabled-extensions "${ativas%]}, '$EXT']" ;;
  esac
  echo "✔ extensão do GNOME instalada: saia da sessão e entre de novo para o"
  echo "  painel ficar preso à área de trabalho"
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "! adicione ~/.local/bin ao seu PATH para usar os comandos no terminal" ;;
esac

echo
echo "Abra agora com: constancia painel"
