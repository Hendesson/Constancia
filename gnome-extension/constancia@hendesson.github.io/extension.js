// Prende a janela do painel do Constância à área de trabalho:
// atrás das outras janelas, em todas as áreas de trabalho e na posição salva.
import GLib from 'gi://GLib';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const APP_ID = 'io.github.hendesson.constancia';
const TITULO = 'Constância';
const MARGEM = 24;

export default class ConstanciaExtension extends Extension {
    enable() {
        this._arquivo = GLib.build_filenamev([GLib.get_user_config_dir(), 'constancia', 'posicao.json']);
        this._fixadas = new Map();   // janela -> ids dos sinais
        this._esperando = new Map(); // janela -> id do sinal 'shown'
        this._timers = new Set();
        this._salvarId = 0;
        this._criada = global.display.connect('window-created', (_d, janela) => this._observar(janela));
        for (const ator of global.get_window_actors())
            this._fixarSeForPainel(ator.meta_window);
    }

    disable() {
        global.display.disconnect(this._criada);
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
            janela.connect('raised', () => janela.lower()),
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
