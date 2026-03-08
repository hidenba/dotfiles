#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, GtkLayerShell, Gdk
import json
import urllib.request
import os
import sys
import signal
import subprocess

CACHE_FILE = "/tmp/keylight-ip"
DEFAULT_IP = "192.168.1.4"
PORT = 9123
CLOSEFILE = "/tmp/keylight-control.closed"

def resolve_ip():
    """Try cached IP, then default IP, then mDNS discovery."""
    # Try cached IP
    if os.path.exists(CACHE_FILE):
        try:
            cached_ip = open(CACHE_FILE).read().strip()
            if cached_ip:
                url = f"http://{cached_ip}:{PORT}/elgato/lights"
                urllib.request.urlopen(url, timeout=1)
                return cached_ip
        except:
            pass

    # Try default IP
    try:
        url = f"http://{DEFAULT_IP}:{PORT}/elgato/lights"
        urllib.request.urlopen(url, timeout=1)
        with open(CACHE_FILE, 'w') as f:
            f.write(DEFAULT_IP)
        return DEFAULT_IP
    except:
        pass

    # Discover via mDNS
    try:
        result = subprocess.run(
            ["avahi-browse", "-t", "-r", "-p", "_elg._tcp"],
            capture_output=True, text=True, timeout=5
        )
        for line in result.stdout.splitlines():
            if line.startswith("=") and "IPv4" in line:
                ip = line.split(";")[7]
                with open(CACHE_FILE, 'w') as f:
                    f.write(ip)
                return ip
    except:
        pass

    return None

def get_keylight_url():
    ip = resolve_ip()
    if ip:
        return f"http://{ip}:{PORT}/elgato/lights"
    return None

def check_toggle():
    import time
    # If panel was closed very recently, this click caused the focus-out, so don't reopen
    if os.path.exists(CLOSEFILE):
        try:
            close_time = os.path.getmtime(CLOSEFILE)
            if time.time() - close_time < 1.0:
                os.remove(CLOSEFILE)
                sys.exit(0)
        except OSError:
            pass
        try:
            os.remove(CLOSEFILE)
        except:
            pass

    # Kill any existing instances
    my_pid = os.getpid()
    result = subprocess.run(["pgrep", "-f", "keylight-control.py"], capture_output=True, text=True)
    if result.stdout:
        for line in result.stdout.strip().split('\n'):
            pid = int(line.strip())
            if pid != my_pid:
                try:
                    os.kill(pid, signal.SIGKILL)
                except (ProcessLookupError, OSError):
                    pass
                sys.exit(0)

def mark_closed():
    try:
        with open(CLOSEFILE, 'w') as f:
            f.write('')
    except:
        pass

def cleanup(*args):
    mark_closed()
    Gtk.main_quit()

def get_state():
    try:
        url = get_keylight_url()
        if not url:
            return None
        with urllib.request.urlopen(url, timeout=2) as r:
            data = json.loads(r.read())
            return data['lights'][0]
    except:
        return None

def set_state(**kwargs):
    try:
        url = get_keylight_url()
        if not url:
            return
        payload = json.dumps({"numberOfLights": 1, "lights": [kwargs]}).encode()
        req = urllib.request.Request(url, data=payload, method='PUT',
                                     headers={'Content-Type': 'application/json'})
        urllib.request.urlopen(req, timeout=2)
    except:
        pass

class KeyLightControl(Gtk.Window):
    def __init__(self):
        super().__init__(title="Key Light")

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 35)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 10)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.connect("key-press-event", self.on_key)
        self._ready = False
        from gi.repository import GLib
        GLib.timeout_add(500, self._enable_focus_out)
        self.connect("focus-out-event", self._on_focus_out)

        state = get_state()
        if not state:
            self.destroy()
            return

        is_on = state['on'] == 1
        brightness = state['brightness']
        temp_mired = state['temperature']
        temp_k = round(1000000 / temp_mired)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.set_margin_top(12)
        vbox.set_margin_bottom(12)
        vbox.set_margin_start(14)
        vbox.set_margin_end(24)

        # ON/OFF button
        self.toggle_btn = Gtk.ToggleButton(label="ON" if is_on else "OFF")
        self.toggle_btn.set_active(is_on)
        self.toggle_btn.connect("toggled", self.on_toggle)
        vbox.pack_start(self.toggle_btn, False, False, 0)

        # Brightness
        br_label = Gtk.Label(label="Brightness")
        br_label.set_halign(Gtk.Align.START)
        vbox.pack_start(br_label, False, False, 0)

        self.br_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 3, 100, 1)
        self.br_scale.set_value(brightness)
        self.br_scale.set_draw_value(False)
        self.br_scale.set_size_request(250, -1)
        self.br_scale.connect("value-changed", self.on_brightness)
        vbox.pack_start(self.br_scale, False, False, 0)

        # Color Temperature
        ct_label = Gtk.Label(label="Color Temperature")
        ct_label.set_halign(Gtk.Align.START)
        vbox.pack_start(ct_label, False, False, 0)

        self.ct_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 2900, 7000, 100)
        self.ct_scale.set_value(temp_k)
        self.ct_scale.set_draw_value(False)
        self.ct_scale.set_size_request(250, -1)
        self.ct_scale.connect("value-changed", self.on_temperature)
        vbox.pack_start(self.ct_scale, False, False, 0)

        self.add(vbox)

        # Apply CSS - reset GTK theme first, then apply custom styles
        settings = Gtk.Settings.get_default()
        settings.set_property("gtk-theme-name", "Adwaita-dark")

        css = Gtk.CssProvider()
        css.load_from_data(b"""
            * {
                all: unset;
            }
            window {
                background-color: rgba(30, 30, 46, 0.3);
                border-radius: 8px;
                border: 2px solid #7aa2f7;
            }
            label {
                color: #c0caf5;
                font-size: 12px;
            }
            button.toggle {
                background-color: rgba(15, 15, 25, 0.8);
                background-image: none;
                color: #707070;
                border: 1px solid #303050;
                border-radius: 4px;
                padding: 2px 12px;
                font-size: 11px;
                box-shadow: none;
                text-shadow: none;
                -gtk-icon-shadow: none;
            }
            button.toggle:checked {
                background-color: rgba(30, 30, 50, 0.8);
                background-image: none;
                color: #9090b0;
                border: 1px solid #505080;
                box-shadow: none;
            }
            scale trough {
                background-color: #414868;
                border-radius: 4px;
                min-height: 6px;
            }
            scale highlight {
                background-color: #7aa2f7;
                border-radius: 4px;
                min-height: 6px;
            }
            scale slider {
                background-color: #c0caf5;
                border-radius: 50%;
                min-width: 12px;
                min-height: 12px;
                margin: -3px 0;
            }
            scale {
                padding: 0 6px;
            }
            scale value {
                color: #c0caf5;
                font-size: 12px;
            }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css, 800
        )

        self.show_all()

    def _enable_focus_out(self):
        self._ready = True
        return False

    def _on_focus_out(self, *args):
        if self._ready:
            self.destroy()

    def on_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def on_toggle(self, btn):
        on = 1 if btn.get_active() else 0
        btn.set_label("ON" if on else "OFF")
        set_state(on=on)

    def on_brightness(self, scale):
        val = int(scale.get_value())
        set_state(brightness=val)

    def on_temperature(self, scale):
        kelvin = int(scale.get_value())
        mired = round(1000000 / kelvin)
        set_state(temperature=mired)

def main():
    check_toggle()
    signal.signal(signal.SIGTERM, cleanup)
    win = KeyLightControl()
    win.connect("destroy", cleanup)
    Gtk.main()

if __name__ == "__main__":
    main()
