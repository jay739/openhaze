// Settings window for OpenHaze (Windows). All changes apply live.
using System;
using System.Drawing;
using System.Windows.Forms;
using Microsoft.Win32;

namespace OpenHaze
{
    internal class SettingsForm : Form
    {
        private readonly HazeSettings settings;
        private readonly Action onHotkeysChanged;

        private CheckBox enabledBox;
        private TrackBar intensityBar;
        private Label intensityValue;
        private TrackBar fadeBar;
        private Label fadeValue;
        private Panel colorSwatch;
        private RadioButton highlightWindow, highlightApp;
        private RadioButton monitorsIndependent, monitorsSingle;
        private RadioButton desktopReveal, desktopDim;
        private TextBox hotkeyToggle, hotkeyInc, hotkeyDec;
        private CheckBox startupBox;

        private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string RunValue = "OpenHaze";

        public SettingsForm(HazeSettings settings, Action onHotkeysChanged)
        {
            this.settings = settings;
            this.onHotkeysChanged = onHotkeysChanged;

            Text = "OpenHaze Settings";
            AutoScaleMode = AutoScaleMode.Dpi;
            AutoScaleDimensions = new SizeF(96F, 96F);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(470, 636);
            Font = new Font("Segoe UI", 9f);

            int y = 12;
            y = BuildDimmingGroup(y);
            y = BuildFocusGroup(y);
            y = BuildMonitorsGroup(y);
            y = BuildShortcutsGroup(y);
            y = BuildSystemGroup(y);

            var close = new Button();
            close.Text = "Close";
            close.Size = new Size(90, 28);
            close.Location = new Point(ClientSize.Width - 102, y + 4);
            close.Click += delegate { Close(); };
            Controls.Add(close);
            AcceptButton = close;

            ClientSize = new Size(470, y + 44);
        }

        // ---- groups ----

        private int BuildDimmingGroup(int y)
        {
            var g = NewGroup("Dimming", y, 168);

            enabledBox = new CheckBox();
            enabledBox.Text = "Dim background windows";
            enabledBox.Checked = settings.Enabled;
            enabledBox.Location = new Point(14, 24);
            enabledBox.AutoSize = true;
            enabledBox.CheckedChanged += delegate
            {
                settings.Enabled = enabledBox.Checked;
                settings.NotifyChanged();
            };
            g.Controls.Add(enabledBox);

            g.Controls.Add(NewLabel("Intensity", 14, 56));
            intensityBar = new TrackBar();
            intensityBar.Minimum = 0; intensityBar.Maximum = 100;
            intensityBar.TickStyle = TickStyle.None;
            intensityBar.SetBounds(90, 50, 280, 30);
            intensityBar.Value = (int)Math.Round(settings.Intensity * 100);
            intensityBar.ValueChanged += delegate
            {
                intensityValue.Text = intensityBar.Value + "%";
                settings.SetIntensity(intensityBar.Value / 100.0);
            };
            g.Controls.Add(intensityBar);
            intensityValue = NewLabel(intensityBar.Value + "%", 380, 56);
            g.Controls.Add(intensityValue);

            g.Controls.Add(NewLabel("Fade", 14, 92));
            fadeBar = new TrackBar();
            fadeBar.Minimum = 0; fadeBar.Maximum = 1500;
            fadeBar.SmallChange = 50; fadeBar.LargeChange = 150;
            fadeBar.TickStyle = TickStyle.None;
            fadeBar.SetBounds(90, 86, 280, 30);
            fadeBar.Value = Math.Min(1500, settings.FadeMs);
            fadeBar.ValueChanged += delegate
            {
                fadeValue.Text = FadeText();
                settings.FadeMs = fadeBar.Value;
                settings.NotifyChanged();
            };
            g.Controls.Add(fadeBar);
            fadeValue = NewLabel(FadeText(), 380, 92);
            g.Controls.Add(fadeValue);

            g.Controls.Add(NewLabel("Haze color", 14, 130));
            colorSwatch = new Panel();
            colorSwatch.SetBounds(90, 128, 40, 20);
            colorSwatch.BackColor = settings.HazeColor;
            colorSwatch.BorderStyle = BorderStyle.FixedSingle;
            g.Controls.Add(colorSwatch);

            var pick = new Button();
            pick.Text = "Choose…";
            pick.SetBounds(140, 125, 80, 26);
            pick.Click += delegate
            {
                using (var dlg = new ColorDialog())
                {
                    dlg.Color = settings.HazeColor;
                    dlg.FullOpen = true;
                    if (dlg.ShowDialog(this) == DialogResult.OK)
                    {
                        settings.HazeColor = dlg.Color;
                        colorSwatch.BackColor = dlg.Color;
                        settings.NotifyChanged();
                    }
                }
            };
            g.Controls.Add(pick);

            var reset = new Button();
            reset.Text = "Black";
            reset.SetBounds(226, 125, 60, 26);
            reset.Click += delegate
            {
                settings.HazeColor = Color.Black;
                colorSwatch.BackColor = Color.Black;
                settings.NotifyChanged();
            };
            g.Controls.Add(reset);

            return y + g.Height + 8;
        }

        private string FadeText()
        {
            return fadeBar.Value == 0 ? "instant" : fadeBar.Value + " ms";
        }

        private int BuildFocusGroup(int y)
        {
            var g = NewGroup("Focus", y, 122);

            highlightWindow = NewRadio("Highlight the active window", 14, 24, settings.HighlightMode == 0);
            highlightApp = NewRadio("Highlight all windows of the active app", 14, 46, settings.HighlightMode == 1);
            highlightWindow.CheckedChanged += delegate
            {
                if (highlightWindow.Checked) { settings.HighlightMode = 0; settings.NotifyChanged(); }
            };
            highlightApp.CheckedChanged += delegate
            {
                if (highlightApp.Checked) { settings.HighlightMode = 1; settings.NotifyChanged(); }
            };
            g.Controls.Add(highlightWindow);
            g.Controls.Add(highlightApp);

            desktopReveal = NewRadio("Desktop focused: reveal (fade the haze out)", 14, 74, settings.DesktopMode == 0);
            desktopDim = NewRadio("Desktop focused: dim all windows", 14, 96, settings.DesktopMode == 1);
            desktopReveal.CheckedChanged += delegate
            {
                if (desktopReveal.Checked) { settings.DesktopMode = 0; settings.NotifyChanged(); }
            };
            desktopDim.CheckedChanged += delegate
            {
                if (desktopDim.Checked) { settings.DesktopMode = 1; settings.NotifyChanged(); }
            };
            g.Controls.Add(desktopReveal);
            g.Controls.Add(desktopDim);

            return y + g.Height + 8;
        }

        private int BuildMonitorsGroup(int y)
        {
            var g = NewGroup(string.Format("Monitors ({0} connected)", Screen.AllScreens.Length), y, 96);

            monitorsIndependent = NewRadio("Independent focus — highlight the top window on every monitor",
                14, 24, settings.MonitorMode == 0);
            monitorsSingle = NewRadio("One focused monitor — fully dim the other monitor(s)",
                14, 46, settings.MonitorMode == 1);
            monitorsIndependent.CheckedChanged += delegate
            {
                if (monitorsIndependent.Checked) { settings.MonitorMode = 0; settings.NotifyChanged(); }
            };
            monitorsSingle.CheckedChanged += delegate
            {
                if (monitorsSingle.Checked) { settings.MonitorMode = 1; settings.NotifyChanged(); }
            };
            g.Controls.Add(monitorsIndependent);
            g.Controls.Add(monitorsSingle);

            var hint = NewLabel("Tip for two monitors: “one focused monitor” makes it instantly obvious which screen you're on.", 14, 70);
            hint.ForeColor = SystemColors.GrayText;
            hint.AutoSize = false;
            hint.Size = new Size(430, 18);
            g.Controls.Add(hint);

            return y + g.Height + 8;
        }

        private int BuildShortcutsGroup(int y)
        {
            var g = NewGroup("Global shortcuts", y, 122);

            g.Controls.Add(NewLabel("Toggle dimming", 14, 26));
            hotkeyToggle = NewHotkeyBox(150, 22, settings.ToggleMods, settings.ToggleVk,
                delegate(uint mods, uint vk) { settings.ToggleMods = mods; settings.ToggleVk = vk; });
            g.Controls.Add(hotkeyToggle);

            g.Controls.Add(NewLabel("Increase intensity", 14, 58));
            hotkeyInc = NewHotkeyBox(150, 54, settings.IncMods, settings.IncVk,
                delegate(uint mods, uint vk) { settings.IncMods = mods; settings.IncVk = vk; });
            g.Controls.Add(hotkeyInc);

            g.Controls.Add(NewLabel("Decrease intensity", 14, 90));
            hotkeyDec = NewHotkeyBox(150, 86, settings.DecMods, settings.DecVk,
                delegate(uint mods, uint vk) { settings.DecMods = mods; settings.DecVk = vk; });
            g.Controls.Add(hotkeyDec);

            var hint = NewLabel("Click a box, press keys. Backspace clears.", 300, 58);
            hint.ForeColor = SystemColors.GrayText;
            g.Controls.Add(hint);

            return y + g.Height + 8;
        }

        private int BuildSystemGroup(int y)
        {
            var g = NewGroup("System", y, 54);

            startupBox = new CheckBox();
            startupBox.Text = "Start OpenHaze when Windows starts";
            startupBox.Location = new Point(14, 22);
            startupBox.AutoSize = true;
            startupBox.Checked = IsStartupEnabled();
            startupBox.CheckedChanged += delegate { SetStartup(startupBox.Checked); };
            g.Controls.Add(startupBox);

            return y + g.Height + 8;
        }

        // ---- helpers ----

        private GroupBox NewGroup(string title, int y, int height)
        {
            var g = new GroupBox();
            g.Text = title;
            g.SetBounds(12, y, ClientSize.Width - 24, height);
            Controls.Add(g);
            return g;
        }

        private static Label NewLabel(string text, int x, int y)
        {
            var l = new Label();
            l.Text = text;
            l.Location = new Point(x, y);
            l.AutoSize = true;
            return l;
        }

        private static RadioButton NewRadio(string text, int x, int y, bool isChecked)
        {
            var r = new RadioButton();
            r.Text = text;
            r.Location = new Point(x, y);
            r.AutoSize = true;
            r.Checked = isChecked;
            return r;
        }

        private delegate void HotkeySetter(uint mods, uint vk);

        private TextBox NewHotkeyBox(int x, int y, uint mods, uint vk, HotkeySetter setter)
        {
            var box = new TextBox();
            box.SetBounds(x, y, 140, 24);
            box.ReadOnly = true;
            box.BackColor = SystemColors.Window;
            box.Text = HotkeyText(mods, vk);
            box.KeyDown += delegate(object sender, KeyEventArgs e)
            {
                e.SuppressKeyPress = true;
                e.Handled = true;
                if (e.KeyCode == Keys.Back || e.KeyCode == Keys.Delete)
                {
                    setter(0, 0);
                    box.Text = "";
                }
                else if (e.KeyCode != Keys.ControlKey && e.KeyCode != Keys.Menu &&
                         e.KeyCode != Keys.ShiftKey && e.KeyCode != Keys.LWin && e.KeyCode != Keys.RWin)
                {
                    uint m = 0;
                    if (e.Control) m |= Native.MOD_CONTROL;
                    if (e.Alt) m |= Native.MOD_ALT;
                    if (e.Shift) m |= Native.MOD_SHIFT;
                    bool isFKey = e.KeyCode >= Keys.F1 && e.KeyCode <= Keys.F24;
                    if (m == 0 && !isFKey)
                    {
                        System.Media.SystemSounds.Beep.Play();
                        return;
                    }
                    setter(m, (uint)e.KeyCode);
                    box.Text = HotkeyText(m, (uint)e.KeyCode);
                }
                settings.NotifyChanged();
                onHotkeysChanged();
            };
            return box;
        }

        private static string HotkeyText(uint mods, uint vk)
        {
            if (vk == 0) return "";
            string s = "";
            if ((mods & Native.MOD_CONTROL) != 0) s += "Ctrl+";
            if ((mods & Native.MOD_ALT) != 0) s += "Alt+";
            if ((mods & Native.MOD_SHIFT) != 0) s += "Shift+";
            if ((mods & Native.MOD_WIN) != 0) s += "Win+";
            return s + ((Keys)vk).ToString();
        }

        // ---- startup registration ----

        private static bool IsStartupEnabled()
        {
            using (var key = Registry.CurrentUser.OpenSubKey(RunKey))
            {
                return key != null && key.GetValue(RunValue) != null;
            }
        }

        private static void SetStartup(bool on)
        {
            using (var key = Registry.CurrentUser.CreateSubKey(RunKey))
            {
                if (key == null) return;
                if (on) key.SetValue(RunValue, "\"" + Application.ExecutablePath + "\"");
                else key.DeleteValue(RunValue, false);
            }
        }
    }
}
