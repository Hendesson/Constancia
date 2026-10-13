// Prende a janela do painel do Constância à área de trabalho (atrás das outras
// janelas, em todas as áreas de trabalho e na posição salva) e põe dois atalhos
// para abri-lo: um ícone na barra superior, ao lado dos ícones do sistema, e um
// botão no menu rápido (o do volume, rede e energia).
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Shell from 'gi://Shell';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

const APP_ID = 'io.github.hendesson.constancia';
const TITULO = 'Constância';
const MARGEM = 24;

// Abre o painel (ou o traz para a frente, se já estiver aberto)
function abrirPainel() {
    Shell.AppSystem.get_default().lookup_app(`${APP_ID}.desktop`)?.activate();
}

// Botão "Constância" no menu rápido
const Atalho = GObject.registerClass(
class Atalho extends QuickSettings.QuickToggle {
    _init(icone) {
        super._init({
            title: TITULO,
            subtitle: 'Abrir o painel',
            gicon: icone,
            toggleMode: false,
        });
        this.connect('clicked', () => {
            Main.panel.closeQuickSettings();
            abrirPainel();
        });
    }
});

const Indicador = GObject.registerClass(
class Indicador extends QuickSettings.SystemIndicator {
    _init(icone) {
        super._init();
        this.quickSettingsItems.push(new Atalho(icone));
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

export default class ConstanciaExtension extends Extension {
    enable() {
        this._arquivo = GLib.build_filenamev([GLib.get_user_config_dir(), 'constancia', 'posicao.json']);
        this._fixadas = new Map();   // janela -> ids dos sinais
        this._esperando = new Map(); // janela -> id do sinal 'shown'
        this._timers = new Set();
        this._salvarId = 0;
        this._criada = global.display.connect('window-created', (_d, janela) => this._observar(janela));
        // O painel fica no fundo, mas vem para a frente enquanto está em uso (ao ser aberto
        // pelo ícone ou clicado) e volta para o fundo quando o foco vai para outra janela.
        this._foco = global.display.connect('notify::focus-window', () => {
            for (const janela of this._fixadas.keys()) {
                if (global.display.focus_window !== janela)
                    janela.lower();
            }
        });
        const icone = Gio.icon_new_for_string(`${this.path}/constancia-symbolic.svg`);
        this._indicador = new Indicador(icone);
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicador);

        // Ícone na barra superior, logo à esquerda dos ícones do sistema: um clique abre o painel
        this._botao = new PanelMenu.Button(0.0, TITULO, true);
        this._botao.add_child(new St.Icon({gicon: icone, style_class: 'system-status-icon'}));
        this._botao.connect('button-press-event', () => {
            abrirPainel();
            return Clutter.EVENT_STOP;
        });
        this._botao.connect('touch-event', (_ator, evento) => {
            if (evento.type() === Clutter.EventType.TOUCH_END)
                abrirPainel();
            return Clutter.EVENT_PROPAGATE;
        });
        const ultimo = Math.max(0, Main.panel._rightBox.get_n_children() - 1);
        Main.panel.addToStatusArea(this.uuid, this._botao, ultimo, 'right');
        for (const ator of global.get_window_actors())
            this._fixarSeForPainel(ator.meta_window);
    }

    disable() {
        global.display.disconnect(this._criada);
        global.display.disconnect(this._foco);
        this._indicador.destroy();
        this._botao.destroy();
        this._indicador = this._botao = null;
        for (const [janela, id] of this._esperando)
            janela.disconnect(id);
        for (const janela of [...this._fixadas.keys()])
            this._soltar(janela, true);
        for (const id of this._timers)
            GLib.source_remove(id);
        if (this._salvarId)
            GLib.source_remove(this._salvarId);
        this._fixadas = this._esperando = this._timers = null;
        this._salvarId = 0;
    }

    // O título e o id do aplicativo só estão definidos quando a janela é exibida
    _observar(janela) {
        const id = janela.connect('shown', () => {
            janela.disconnect(id);
            this._esperando.delete(janela);
            this._fixarSeForPainel(janela);
        });
        this._esperando.set(janela, id);
    }

    _fixarSeForPainel(janela) {
        const doApp = janela.get_gtk_application_id() === APP_ID || janela.get_wm_class() === APP_ID;
        if (!doApp || janela.get_title() !== TITULO || this._fixadas.has(janela))
            return;
        janela.stick();
        janela.lower();
        this._fixadas.set(janela, [
            janela.connect('position-changed', () => this._agendarSalvar(janela)),
            janela.connect('unmanaged', () => this._soltar(janela, false)),
        ]);
        this._depois(200, () => this._posicionar(janela));
    }

    _soltar(janela, restaurar) {
        for (const id of this._fixadas.get(janela) ?? [])
            janela.disconnect(id);
        this._fixadas.delete(janela);
        if (restaurar)
            janela.unstick();
    }

    _depois(ms, fn) {
        const id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
            this._timers.delete(id);
            fn();
            return GLib.SOURCE_REMOVE;
        });
        this._timers.add(id);
    }

    _posicionar(janela) {
        if (!this._fixadas.has(janela))
            return;
        const area = Main.layoutManager.getWorkAreaForMonitor(Main.layoutManager.primaryIndex);
        let x = area.x + area.width - janela.get_frame_rect().width - MARGEM;
        let y = area.y + MARGEM;
        try {
            const [, bytes] = GLib.file_get_contents(this._arquivo);
            const salva = JSON.parse(new TextDecoder().decode(bytes));
            const visivel = Main.layoutManager.monitors.some(m =>
                salva.x >= m.x && salva.x < m.x + m.width && salva.y >= m.y && salva.y < m.y + m.height);
            if (visivel)
                [x, y] = [salva.x, salva.y];
        } catch {
            // sem posição salva: fica no canto superior direito
        }
        janela.move_frame(true, x, y);
    }

    _agendarSalvar(janela) {
        if (this._salvarId)
            GLib.source_remove(this._salvarId);
        this._salvarId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            this._salvarId = 0;
            if (this._fixadas.has(janela)) {
                const r = janela.get_frame_rect();
                GLib.mkdir_with_parents(GLib.path_get_dirname(this._arquivo), 0o755);
                GLib.file_set_contents(this._arquivo, JSON.stringify({x: r.x, y: r.y}));
            }
            return GLib.SOURCE_REMOVE;
        });
    }
}
