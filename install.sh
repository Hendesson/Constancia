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

if python3 -c 'import gi; gi.require_version("Gtk", "4.0")' >/dev/null 2>&1; then
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
Icon=x-office-calendar
Categories=Utility;
FIM
  cp "$HOME/.local/share/applications/$ATALHO" "$HOME/.config/autostart/$ATALHO"
  echo "✔ painel no menu de aplicativos e abrindo sozinho ao entrar na sessão"
else
  echo "! GTK 4 para Python não encontrado: o painel não vai abrir"
  echo "  (Debian/Ubuntu: sudo apt install python3-gi gir1.2-gtk-4.0)"
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
