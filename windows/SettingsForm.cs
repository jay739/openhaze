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
        private CheckBox separateBox;
        private Control[] darkRows;     // greyed out until separateBox is on
        private TrackBar fadeBar;
        private Label fadeValue;
        private RadioButton highlightWindow, highlightApp;
        private RadioButton monitorsIndependent, monitorsSingle;
        private RadioButton desktopReveal, desktopDim;
        private TextBox hotkeyToggle, hotkeyInc, hotkeyDec;
        private CheckBox startupBox;
        private CheckBox updatesBox;

        private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string RunValue = "OpenHaze";

        // Colors for when Windows is in dark mode, close to Windows 11's own
        // dark windows.
        private static readonly Color DarkBack = Color.FromArgb(32, 32, 32);
        private static readonly Color DarkField = Color.FromArgb(45, 45, 45);
        private static readonly Color DarkFieldHover = Color.FromArgb(60, 60, 60);
        private static readonly Color DarkBorder = Color.FromArgb(90, 90, 90);
        private static readonly Color DarkText = Color.White;
        private static readonly Color DarkHintText = Color.FromArgb(160, 160, 160);
        private static readonly Color DarkDisabledText = Color.FromArgb(110, 110, 110);

        private static readonly object HintTag = new object();   // marks grey helper text

        private bool darkTheme;   // the window is drawn dark (settings.UseDarkTheme)

        private const int DarkRowIndent = 20;   // the rows the dark-mode switch controls

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

            // Light or dark as the Theme setting says, and again whenever that or
            // (on "Match Windows") Windows' own mode changes while this is open.
            ApplyTheme(settings.UseDarkTheme);
            settings.Changed += OnSettingsChanged;
        }

        // Windows draws the title bar itself, so it is switched separately, as
        // soon as the window exists and before it first shows.
        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            if (darkTheme) Native.SetDarkTitleBar(Handle, true);
        }

        // The settings outlive this window, so stop listening to them.
        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            settings.Changed -= OnSettingsChanged;
            base.OnFormClosed(e);
        }

        // Changed fires for every setting saved from this window as well as when
        // Windows switches theme, so this acts only when the look should change.
        private void OnSettingsChanged()
        {
            if (IsDisposed || settings.UseDarkTheme == darkTheme) return;
            if (InvokeRequired)
            {
                BeginInvoke(new Action(OnSettingsChanged));
                return;
            }
            ApplyTheme(settings.UseDarkTheme);
            Invalidate(true);
        }

        // Draws the window light or dark.
        private void ApplyTheme(bool dark)
        {
            darkTheme = dark;
            if (IsHandleCreated) Native.SetDarkTitleBar(Handle, dark);
            if (dark)
            {
                BackColor = DarkBack;
                ForeColor = DarkText;
            }
            else
            {
                ResetBackColor();
                ResetForeColor();
            }
            ApplyColors(Controls, dark);
            // After the colors, because in dark mode greying out sets a color too.
            SetEnabled(darkRows, settings.SeparateAppearance);
        }

        // WinForms has no dark theme of its own, so each control gets its dark
        // colors here, and the normal ones back when Windows turns light again.
        private static void ApplyColors(Control.ControlCollection controls, bool dark)
        {
            foreach (Control c in controls)
            {
                var button = c as Button;
                var box = c as TextBox;
                if (button != null)
                {
                    // A standard button is drawn by the Windows theme, which
                    // ignores BackColor, so in dark mode it is drawn flat.
                    if (dark)
                    {
                        button.FlatStyle = FlatStyle.Flat;
                        button.BackColor = DarkField;
                        button.ForeColor = DarkText;
                        button.FlatAppearance.BorderColor = DarkBorder;
                        button.FlatAppearance.MouseOverBackColor = DarkFieldHover;
                        button.FlatAppearance.MouseDownBackColor = DarkBack;
                    }
                    else
                    {
                        button.FlatStyle = FlatStyle.Standard;
                        button.ResetBackColor();
                        button.ResetForeColor();
                        button.UseVisualStyleBackColor = true;   // ResetBackColor clears it
                    }
                }
                else if (box != null)
                {
                    // The shortcut boxes are read-only, which would turn them grey,
                    // so their light background is set too.
                    box.BackColor = dark ? DarkField : SystemColors.Window;
                    if (dark) box.ForeColor = DarkText; else box.ResetForeColor();
                    box.BorderStyle = dark ? BorderStyle.FixedSingle : BorderStyle.Fixed3D;
                }
                else if (c is TrackBar)
                {
                    if (dark) c.BackColor = DarkBack; else c.ResetBackColor();
                }
                else if (c is Panel)
                {
                    // A color swatch keeps showing its haze color.
                }
                else
                {
                    // Labels, checkboxes, radio buttons and group boxes. Hints
                    // stay dimmer than the rest of the text.
                    if (c.Tag == HintTag) c.ForeColor = dark ? DarkHintText : SystemColors.GrayText;
                    else if (dark) c.ForeColor = DarkText;
                    else c.ResetForeColor();
                    ApplyColors(c.Controls, dark);
                }
            }
        }

        // ---- groups ----

        private int BuildDimmingGroup(int y)
        {
            var g = NewGroup("Dimming", y, 292);

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

            // Each slider sets its own stored value. SetIntensity would change
            // whichever value is in effect right now instead. A TrackBar sizes
            // itself to 45 px whatever height it is given, so the row under a
            // slider starts 48 px below its top; any closer and the slider
            // covers part of that row and takes its clicks.
            AddIntensityRow(g, "Intensity", 0, 50, settings.Intensity,
                delegate(double v) { settings.Intensity = v; settings.NotifyChanged(); });

            g.Controls.Add(NewLabel("Fade", 14, 104));
            fadeBar = new TrackBar();
            fadeBar.Minimum = 0; fadeBar.Maximum = 1500;
            fadeBar.SmallChange = 50; fadeBar.LargeChange = 150;
            fadeBar.TickStyle = TickStyle.None;
            fadeBar.SetBounds(90, 98, 280, 30);
            fadeBar.Value = Math.Min(1500, settings.FadeMs);
            fadeBar.ValueChanged += delegate
            {
                fadeValue.Text = FadeText();
                settings.FadeMs = fadeBar.Value;
                settings.NotifyChanged();
            };
            g.Controls.Add(fadeBar);
            fadeValue = NewLabel(FadeText(), 380, 104);
            g.Controls.Add(fadeValue);

            AddColorRow(g, "Haze color", 0, 146, delegate { return settings.HazeColor; },
                delegate(Color c) { settings.HazeColor = c; settings.NotifyChanged(); });

            // The indented rows under this switch apply while Windows is in dark
            // mode, and only when it is on.
            separateBox = new CheckBox();
            separateBox.Text = "Use a different haze intensity and color when Windows is in dark mode";
            separateBox.Checked = settings.SeparateAppearance;
            separateBox.Location = new Point(14, 180);
            separateBox.AutoSize = true;
            separateBox.CheckedChanged += delegate
            {
                settings.SeparateAppearance = separateBox.Checked;
                settings.NotifyChanged();
                SetEnabled(darkRows, separateBox.Checked);
            };
            g.Controls.Add(separateBox);

            Control[] darkIntensity = AddIntensityRow(g, "Intensity", DarkRowIndent, 204, settings.IntensityDark,
                delegate(double v) { settings.IntensityDark = v; settings.NotifyChanged(); });
            Control[] darkColor = AddColorRow(g, "Haze color", DarkRowIndent, 252, delegate { return settings.HazeColorDark; },
                delegate(Color c) { settings.HazeColorDark = c; settings.NotifyChanged(); });

            darkRows = new Control[darkIntensity.Length + darkColor.Length];
            darkIntensity.CopyTo(darkRows, 0);
            darkColor.CopyTo(darkRows, darkIntensity.Length);

            return y + g.Height + 8;
        }

        // A labelled 0 to 100% slider; apply receives the new value as 0..1.
        // indent moves the row right while the value column stays aligned.
        private Control[] AddIntensityRow(GroupBox g, string title, int indent, int y, double initial, Action<double> apply)
        {
            var label = NewLabel(title, 14 + indent, y + 6);
            var bar = new TrackBar();
            bar.Minimum = 0; bar.Maximum = 100;
            bar.TickStyle = TickStyle.None;
            bar.SetBounds(90 + indent, y, 280 - indent, 30);
            bar.Value = (int)Math.Round(initial * 100);
            var shown = NewLabel(bar.Value + "%", 380, y + 6);
            bar.ValueChanged += delegate
            {
                shown.Text = bar.Value + "%";
                apply(bar.Value / 100.0);
            };
            g.Controls.Add(label);
            g.Controls.Add(bar);
            g.Controls.Add(shown);
            return new Control[] { label, bar, shown };
        }

        // A labelled color swatch with "Choose…" and "Black" buttons.
        private Control[] AddColorRow(GroupBox g, string title, int indent, int y, Func<Color> get, Action<Color> set)
        {
            var label = NewLabel(title, 14 + indent, y + 2);
            var swatch = new Panel();
            swatch.SetBounds(90 + indent, y, 40, 20);
            swatch.BackColor = get();
            swatch.BorderStyle = BorderStyle.FixedSingle;

            var pick = new Button();
            pick.Text = "Choose…";
            pick.SetBounds(140 + indent, y - 3, 80, 26);
            pick.Click += delegate
            {
                using (var dlg = new ColorDialog())
                {
                    dlg.Color = get();
                    dlg.FullOpen = true;
                    if (dlg.ShowDialog(this) == DialogResult.OK)
                    {
                        set(dlg.Color);
                        swatch.BackColor = dlg.Color;
                    }
                }
            };

            var reset = new Button();
            reset.Text = "Black";
            reset.SetBounds(226 + indent, y - 3, 60, 26);
            reset.Click += delegate
            {
                set(Color.Black);
                swatch.BackColor = Color.Black;
            };

            g.Controls.Add(label);
            g.Controls.Add(swatch);
            g.Controls.Add(pick);
            g.Controls.Add(reset);
            return new Control[] { label, swatch, pick, reset };
        }

        // Greys rows out. In dark mode a label is dimmed by color instead,
        // because Windows draws disabled label text with a light shadow that
        // smudges on a dark background.
        private void SetEnabled(Control[] controls, bool enabled)
        {
            foreach (var c in controls)
            {
                if (darkTheme && c is Label)
                {
                    c.Enabled = true;   // it may have been disabled while Windows was light
                    c.ForeColor = enabled ? DarkText : DarkDisabledText;
                }
                else c.Enabled = enabled;
            }
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
            var g = NewGroup(string.Format("Monitors ({0} connected)", Screen.AllScreens.Length), y, 116);

            monitorsIndependent = NewRadio("Independent focus: highlight the top window on every monitor",
                14, 24, settings.MonitorMode == 0);
            monitorsSingle = NewRadio("One focused monitor: fully dim the other monitor(s)",
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

            var hint = NewHint("Tip for two monitors: “one focused monitor” makes it instantly obvious which screen you're on.", 14, 70);
            // Both hints are wider than the window, so each wraps onto two lines
            // in a fixed box; the box scales with the window, so it still fits
            // at other display scalings.
            hint.AutoSize = false;
            hint.Size = new Size(418, 34);
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

            var hint = NewHint("Click a box, press keys. Backspace clears.", 300, 52);
            hint.AutoSize = false;
            hint.Size = new Size(140, 34);
            g.Controls.Add(hint);

            return y + g.Height + 8;
        }

        private int BuildSystemGroup(int y)
        {
            var g = NewGroup("System", y, 108);

            startupBox = new CheckBox();
            startupBox.Text = "Start OpenHaze when Windows starts";
            startupBox.Location = new Point(14, 22);
            startupBox.AutoSize = true;
            startupBox.Checked = IsStartupEnabled();
            startupBox.CheckedChanged += delegate { SetStartup(startupBox.Checked); };
            g.Controls.Add(startupBox);

            // Notify-only: it opens the release page, never downloads anything.
            updatesBox = new CheckBox();
            updatesBox.Text = "Check GitHub for a new version once a day";
            updatesBox.Location = new Point(14, 48);
            updatesBox.AutoSize = true;
            updatesBox.Checked = settings.CheckForUpdates;
            updatesBox.CheckedChanged += delegate
            {
                settings.CheckForUpdates = updatesBox.Checked;
                settings.NotifyChanged();
            };
            g.Controls.Add(updatesBox);

            // Light or dark for this window only. The haze's dark-mode values
            // follow Windows whatever this says.
            g.Controls.Add(NewLabel("Theme", 14, 80));
            AddThemeChoice(g, "Match Windows", 70, 0);
            AddThemeChoice(g, "Light", 190, 1);
            AddThemeChoice(g, "Dark", 260, 2);

            return y + g.Height + 8;
        }

        private void AddThemeChoice(GroupBox g, string text, int x, int mode)
        {
            var r = NewRadio(text, x, 78, settings.ThemeMode == mode);
            r.CheckedChanged += delegate
            {
                if (r.Checked) { settings.ThemeMode = mode; settings.NotifyChanged(); }
            };
            g.Controls.Add(r);
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

        // Grey helper text, tagged so the theme can tell it from other labels.
        private static Label NewHint(string text, int x, int y)
        {
            var l = NewLabel(text, x, y);
            l.ForeColor = SystemColors.GrayText;
            l.Tag = HintTag;
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
