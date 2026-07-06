// OpenHaze for Windows — dims background windows so the active one stands out.
// Personal-use recreation of HazeOver (hazeover.com). C# 5 / .NET Framework 4.8 /
// WinForms: builds with the csc.exe bundled in every Windows 10/11 install.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;
using FormsTimer = System.Windows.Forms.Timer;

namespace OpenHaze
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            bool createdNew;
            using (var mutex = new Mutex(true, "OpenHaze.SingleInstance", out createdNew))
            {
                if (!createdNew)
                {
                    MessageBox.Show("OpenHaze is already running (check the tray).",
                        "OpenHaze", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new TrayContext());
            }
        }
    }

    // ------------------------------------------------------------------ Settings

    internal class HazeSettings
    {
        public bool Enabled;
        public double Intensity;        // 0..1
        public int FadeMs;              // 0 = instant
        public Color HazeColor;
        public int HighlightMode;       // 0 = active window, 1 = all windows of active app
        public int MonitorMode;         // 0 = independent per monitor, 1 = focus one monitor
        public int DesktopMode;         // 0 = reveal when desktop focused, 1 = dim everything
        public uint ToggleMods; public uint ToggleVk;
        public uint IncMods; public uint IncVk;
        public uint DecMods; public uint DecVk;

        public event Action Changed;
        public void NotifyChanged() { Save(); var h = Changed; if (h != null) h(); }

        public HazeSettings()
        {
            Enabled = true;
            Intensity = 0.35;
            FadeMs = 300;
            HazeColor = Color.Black;
            HighlightMode = 0;
            MonitorMode = 0;
            DesktopMode = 0;
            ToggleMods = Native.MOD_CONTROL | Native.MOD_ALT; ToggleVk = (uint)Keys.H;
            IncMods = 0; IncVk = 0;
            DecMods = 0; DecVk = 0;
        }

        private static string PathFor()
        {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "OpenHaze");
            Directory.CreateDirectory(dir);
            return Path.Combine(dir, "settings.txt");
        }

        public static HazeSettings Load()
        {
            var s = new HazeSettings();
            try
            {
                if (File.Exists(PathFor()))
                {
                    foreach (var line in File.ReadAllLines(PathFor()))
                    {
                        int eq = line.IndexOf('=');
                        if (eq < 1) continue;
                        string k = line.Substring(0, eq).Trim();
                        string v = line.Substring(eq + 1).Trim();
                        switch (k)
                        {
                            case "Enabled": s.Enabled = v == "1"; break;
                            case "Intensity": s.Intensity = Clamp01(ParseD(v, 0.35)); break;
                            case "FadeMs": s.FadeMs = Math.Max(0, Math.Min(2000, ParseI(v, 300))); break;
                            case "HazeColor": s.HazeColor = ParseColor(v); break;
                            case "HighlightMode": s.HighlightMode = ParseI(v, 0); break;
                            case "MonitorMode": s.MonitorMode = ParseI(v, 0); break;
                            case "DesktopMode": s.DesktopMode = ParseI(v, 0); break;
                            case "ToggleMods": s.ToggleMods = (uint)ParseI(v, 0); break;
                            case "ToggleVk": s.ToggleVk = (uint)ParseI(v, 0); break;
                            case "IncMods": s.IncMods = (uint)ParseI(v, 0); break;
                            case "IncVk": s.IncVk = (uint)ParseI(v, 0); break;
                            case "DecMods": s.DecMods = (uint)ParseI(v, 0); break;
                            case "DecVk": s.DecVk = (uint)ParseI(v, 0); break;
                        }
                    }
                }
            }
            catch { }
            return s;
        }

        public void Save()
        {
            try
            {
                var lines = new[]
                {
                    "Enabled=" + (Enabled ? "1" : "0"),
                    "Intensity=" + Intensity.ToString(System.Globalization.CultureInfo.InvariantCulture),
                    "FadeMs=" + FadeMs,
                    "HazeColor=" + HazeColor.R + "," + HazeColor.G + "," + HazeColor.B,
                    "HighlightMode=" + HighlightMode,
                    "MonitorMode=" + MonitorMode,
                    "DesktopMode=" + DesktopMode,
                    "ToggleMods=" + ToggleMods, "ToggleVk=" + ToggleVk,
                    "IncMods=" + IncMods, "IncVk=" + IncVk,
                    "DecMods=" + DecMods, "DecVk=" + DecVk,
                };
                File.WriteAllLines(PathFor(), lines);
            }
            catch { }
        }

        public void SetIntensity(double v)
        {
            Intensity = Clamp01(v);
            NotifyChanged();
        }

        private static double Clamp01(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
        private static double ParseD(string v, double d)
        {
            double r;
            return double.TryParse(v, System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture, out r) ? r : d;
        }
        private static int ParseI(string v, int d) { int r; return int.TryParse(v, out r) ? r : d; }
        private static Color ParseColor(string v)
        {
            var p = v.Split(',');
            if (p.Length == 3)
            {
                int r, g, b;
                if (int.TryParse(p[0], out r) && int.TryParse(p[1], out g) && int.TryParse(p[2], out b))
                    return Color.FromArgb(r & 255, g & 255, b & 255);
            }
            return Color.Black;
        }
    }

    // ------------------------------------------------------------------ Overlay

    internal class OverlayForm : Form
    {
        public double TargetOpacity;
        public bool HideWhenFadedOut;
        public bool Placed;   // currently participating in the z-order

        public OverlayForm(Rectangle bounds, Color color)
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            Bounds = bounds;
            BackColor = color;
            Opacity = 0;
            TargetOpacity = 0;
            Text = "OpenHaze overlay";
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ExStyle |= Native.WS_EX_LAYERED | Native.WS_EX_TRANSPARENT |
                              Native.WS_EX_NOACTIVATE | Native.WS_EX_TOOLWINDOW;
                return cp;
            }
        }

        public void PlaceBelow(IntPtr anchor)
        {
            Native.SetWindowPos(Handle, anchor, 0, 0, 0, 0,
                Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW);
            Placed = true;
        }

        public void PlaceTopOfNormalBand()
        {
            Native.SetWindowPos(Handle, Native.HWND_TOP, 0, 0, 0, 0,
                Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW);
            Placed = true;
        }

        public void Unplace()
        {
            Native.ShowWindow(Handle, Native.SW_HIDE);
            Placed = false;
        }
    }

    // ------------------------------------------------------------------ Engine

    internal enum PlanKind { Hidden, FullDim, Below }

    internal struct Plan
    {
        public PlanKind Kind;
        public IntPtr Anchor;
        public static Plan Hidden() { return new Plan { Kind = PlanKind.Hidden }; }
        public static Plan FullDim() { return new Plan { Kind = PlanKind.FullDim }; }
        public static Plan Below(IntPtr a) { return new Plan { Kind = PlanKind.Below, Anchor = a }; }
        public bool SameAs(Plan other) { return Kind == other.Kind && Anchor == other.Anchor; }
    }

    internal class MonitorState
    {
        public Screen Screen;
        public OverlayForm A;
        public OverlayForm B;
        public bool ActiveIsA = true;
        public Plan Current = Plan.Hidden();
        public OverlayForm Active { get { return ActiveIsA ? A : B; } }
        public OverlayForm Spare { get { return ActiveIsA ? B : A; } }
        public void Swap() { ActiveIsA = !ActiveIsA; }
    }

    internal class WinInfo
    {
        public IntPtr Hwnd;
        public uint Pid;
        public string Device;   // Screen.DeviceName the window's center falls on
        public int ZIndex;
    }

    internal class HazeEngine : IDisposable
    {
        private readonly HazeSettings settings;
        private readonly List<MonitorState> monitors = new List<MonitorState>();
        private readonly HashSet<IntPtr> overlayHandles = new HashSet<IntPtr>();
        private readonly FormsTimer pollTimer = new FormsTimer();
        private readonly FormsTimer fadeTimer = new FormsTimer();
        private Native.WinEventDelegate winEventProc;  // kept referenced so GC can't collect it
        private readonly List<IntPtr> eventHooks = new List<IntPtr>();
        private uint ownPid;

        public HazeEngine(HazeSettings settings)
        {
            this.settings = settings;
            ownPid = (uint)System.Diagnostics.Process.GetCurrentProcess().Id;

            RebuildMonitors();

            winEventProc = OnWinEvent;
            eventHooks.Add(Native.SetWinEventHook(Native.EVENT_SYSTEM_FOREGROUND, Native.EVENT_SYSTEM_FOREGROUND,
                IntPtr.Zero, winEventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT | Native.WINEVENT_SKIPOWNPROCESS));
            eventHooks.Add(Native.SetWinEventHook(Native.EVENT_SYSTEM_MINIMIZESTART, Native.EVENT_SYSTEM_MINIMIZEEND,
                IntPtr.Zero, winEventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT | Native.WINEVENT_SKIPOWNPROCESS));

            pollTimer.Interval = 200;   // safety net: z-order drift, missed events
            pollTimer.Tick += delegate { Recompute(); };
            pollTimer.Start();

            fadeTimer.Interval = 15;    // ~66 fps opacity animation
            fadeTimer.Tick += delegate { StepFades(); };
            fadeTimer.Start();

            settings.Changed += Recompute;
            SystemEvents.DisplaySettingsChanged += OnDisplaysChanged;
            Recompute();
        }

        private void OnDisplaysChanged(object sender, EventArgs e)
        {
            RebuildMonitors();
            Recompute();
        }

        private void OnWinEvent(IntPtr hook, uint eventType, IntPtr hwnd, int idObject,
            int idChild, uint thread, uint time)
        {
            if (idObject != 0) return;   // OBJID_WINDOW only
            Recompute();
        }

        public void RebuildMonitors()
        {
            foreach (var m in monitors)
            {
                m.A.Close(); m.A.Dispose();
                m.B.Close(); m.B.Dispose();
            }
            monitors.Clear();
            overlayHandles.Clear();

            foreach (var screen in Screen.AllScreens)
            {
                var state = new MonitorState { Screen = screen };
                state.A = new OverlayForm(screen.Bounds, settings.HazeColor);
                state.B = new OverlayForm(screen.Bounds, settings.HazeColor);
                // Create handles up front (never activated, initially hidden)
                state.A.Show(); state.A.Unplace();
                state.B.Show(); state.B.Unplace();
                overlayHandles.Add(state.A.Handle);
                overlayHandles.Add(state.B.Handle);
                monitors.Add(state);
            }
        }

        // ---- planning ----

        public void Recompute()
        {
            List<WinInfo> candidates;
            Dictionary<IntPtr, int> zIndex;
            Snapshot(out candidates, out zIndex);

            IntPtr fg = Native.GetForegroundWindow();
            bool desktopFocused = false;

            if (fg == IntPtr.Zero || !Native.IsWindow(fg) || !Native.IsWindowVisible(fg) || Native.IsCloaked(fg))
            {
                desktopFocused = true;
            }
            else
            {
                string cls = Native.ClassNameOf(fg);
                if (cls == "Progman" || cls == "WorkerW") desktopFocused = true;
            }

            // If our own tray menu/popup is foreground (not a real window like the
            // settings form), keep highlighting the top real window instead.
            if (!desktopFocused && fg != IntPtr.Zero)
            {
                uint fgPid; Native.GetWindowThreadProcessId(fg, out fgPid);
                if (fgPid == ownPid)
                {
                    IntPtr fgCopy = fg;
                    bool isRealWindow = candidates.Any(delegate(WinInfo w) { return w.Hwnd == fgCopy; });
                    if (!isRealWindow)
                    {
                        if (candidates.Count > 0) fg = candidates[0].Hwnd;
                        else desktopFocused = true;
                    }
                }
            }

            foreach (var state in monitors)
            {
                Plan plan = ComputePlan(state, fg, desktopFocused, candidates);
                Apply(plan, state, zIndex);
            }
        }

        private Plan ComputePlan(MonitorState state, IntPtr fg, bool desktopFocused, List<WinInfo> candidates)
        {
            if (!settings.Enabled) return Plan.Hidden();

            if (desktopFocused)
                return settings.DesktopMode == 1 ? Plan.FullDim() : Plan.Hidden();

            string device = state.Screen.DeviceName;
            string fgDevice = Screen.FromHandle(fg).DeviceName;
            bool isFgMonitor = fgDevice == device;
            var onThis = candidates.Where(delegate(WinInfo w) { return w.Device == device; }).ToList();

            if (settings.MonitorMode == 1)   // focus one monitor, dim the rest
            {
                if (!isFgMonitor) return Plan.FullDim();
                return AnchorPlan(fg, onThis);
            }

            // independent focus per monitor
            if (isFgMonitor) return AnchorPlan(fg, onThis);
            if (onThis.Count > 0) return AnchorPlan(onThis[0].Hwnd, onThis);
            return Plan.Hidden();   // empty monitor: nothing to dim
        }

        private Plan AnchorPlan(IntPtr highlight, List<WinInfo> onThisMonitor)
        {
            if (settings.HighlightMode == 1)   // all windows of the app
            {
                uint pid; Native.GetWindowThreadProcessId(highlight, out pid);
                var same = onThisMonitor.Where(delegate(WinInfo w) { return w.Pid == pid; }).ToList();
                if (same.Count > 0) return Plan.Below(same[same.Count - 1].Hwnd);  // bottom-most
            }
            return Plan.Below(highlight);
        }

        /// Snapshot the top-level z-order (top to bottom), filtered to windows a
        /// user would consider "real" — the same set Alt-Tab roughly shows.
        private void Snapshot(out List<WinInfo> candidates, out Dictionary<IntPtr, int> zIndex)
        {
            candidates = new List<WinInfo>();
            zIndex = new Dictionary<IntPtr, int>();
            int index = 0;

            for (IntPtr h = Native.GetTopWindow(IntPtr.Zero); h != IntPtr.Zero; h = Native.GetWindow(h, Native.GW_HWNDNEXT))
            {
                index++;
                zIndex[h] = index;

                if (overlayHandles.Contains(h)) continue;
                if (!Native.IsWindowVisible(h) || Native.IsIconic(h) || Native.IsCloaked(h)) continue;

                int ex = Native.GetWindowLong(h, Native.GWL_EXSTYLE);
                if ((ex & Native.WS_EX_TOOLWINDOW) != 0) continue;
                if (Native.GetWindow(h, Native.GW_OWNER) != IntPtr.Zero) continue;

                Native.RECT r;
                if (!Native.GetWindowRect(h, out r)) continue;
                if (r.Right - r.Left < 40 || r.Bottom - r.Top < 40) continue;

                string cls = Native.ClassNameOf(h);
                if (cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd" ||
                    cls == "Shell_SecondaryTrayWnd" || cls == "NotifyIconOverflowWindow") continue;

                uint pid; Native.GetWindowThreadProcessId(h, out pid);
                candidates.Add(new WinInfo
                {
                    Hwnd = h,
                    Pid = pid,
                    Device = Screen.FromHandle(h).DeviceName,
                    ZIndex = index,
                });
            }
        }

        // ---- applying ----

        private void Apply(Plan plan, MonitorState state, Dictionary<IntPtr, int> zIndex)
        {
            if (state.A.BackColor != settings.HazeColor)
            {
                state.A.BackColor = settings.HazeColor;
                state.B.BackColor = settings.HazeColor;
            }

            double intensity = settings.Intensity;

            if (plan.SameAs(state.Current))
            {
                // Drift: if the overlay ended up above its anchor, tuck it back under.
                if (plan.Kind == PlanKind.Below)
                {
                    int anchorZ, overlayZ;
                    if (zIndex.TryGetValue(plan.Anchor, out anchorZ) &&
                        zIndex.TryGetValue(state.Active.Handle, out overlayZ) &&
                        overlayZ < anchorZ)
                    {
                        state.Active.PlaceBelow(plan.Anchor);
                    }
                }
                // Track live intensity scrubbing.
                if (plan.Kind != PlanKind.Hidden)
                    state.Active.TargetOpacity = intensity;
                return;
            }

            state.Current = plan;

            switch (plan.Kind)
            {
                case PlanKind.Hidden:
                    state.Active.TargetOpacity = 0;
                    state.Active.HideWhenFadedOut = true;
                    break;

                case PlanKind.FullDim:
                case PlanKind.Below:
                    var incoming = state.Spare;
                    var outgoing = state.Active;
                    incoming.Opacity = 0;
                    incoming.HideWhenFadedOut = false;
                    if (plan.Kind == PlanKind.Below) incoming.PlaceBelow(plan.Anchor);
                    else incoming.PlaceTopOfNormalBand();
                    state.Swap();
                    incoming.TargetOpacity = intensity;
                    outgoing.TargetOpacity = 0;
                    outgoing.HideWhenFadedOut = true;
                    break;
            }

            if (settings.FadeMs == 0) StepFades();   // apply instantly
        }

        private void StepFades()
        {
            double step = settings.FadeMs <= 0 ? 1.0 : (double)fadeTimer.Interval / settings.FadeMs;
            foreach (var state in monitors)
            {
                StepForm(state.A, step);
                StepForm(state.B, step);
            }
        }

        private static void StepForm(OverlayForm f, double step)
        {
            double current = f.Opacity;
            double target = f.TargetOpacity;
            if (Math.Abs(current - target) < 0.004)
            {
                if (current != target) f.Opacity = target;
                if (target == 0 && f.HideWhenFadedOut && f.Placed) f.Unplace();
                return;
            }
            double next = current < target ? Math.Min(target, current + step) : Math.Max(target, current - step);
            f.Opacity = next;
            if (next == 0 && f.HideWhenFadedOut && f.Placed) f.Unplace();
        }

        public void Dispose()
        {
            foreach (var h in eventHooks) Native.UnhookWinEvent(h);
            pollTimer.Stop(); fadeTimer.Stop();
            SystemEvents.DisplaySettingsChanged -= OnDisplaysChanged;
            foreach (var m in monitors) { m.A.Close(); m.B.Close(); }
        }
    }

    // ------------------------------------------------------------------ Tray

    internal class TrayContext : ApplicationContext
    {
        private readonly HazeSettings settings;
        private readonly HazeEngine engine;
        private readonly NotifyIcon tray;
        private readonly ContextMenuStrip menu;
        private ToolStripMenuItem toggleItem;
        private TrackBar slider;
        private ToolStripLabel percentLabel;
        private SettingsForm settingsForm;
        private readonly HotkeyWindow hotkeys;
        private IntPtr mouseHook = IntPtr.Zero;
        private Native.LowLevelMouseProc mouseProc;   // kept referenced for GC
        private readonly SynchronizationContext ui;

        public TrayContext()
        {
            settings = HazeSettings.Load();
            engine = new HazeEngine(settings);
            // Overlay Forms exist by now, so WinForms has installed its context.
            ui = SynchronizationContext.Current ?? new SynchronizationContext();

            menu = BuildMenu();
            tray = new NotifyIcon();
            tray.Icon = TrayIconRenderer.Make(settings.Enabled);
            tray.Text = "OpenHaze — double-click to toggle, scroll to adjust";
            tray.ContextMenuStrip = menu;
            tray.Visible = true;
            tray.MouseUp += OnTrayMouseUp;
            tray.DoubleClick += delegate { ToggleEnabled(); };

            hotkeys = new HotkeyWindow(OnHotkey);
            ReRegisterHotkeys();

            settings.Changed += OnSettingsChanged;

            mouseProc = MouseHookProc;
            mouseHook = Native.SetWindowsHookEx(Native.WH_MOUSE_LL, mouseProc,
                Native.GetModuleHandle(null), 0);

            Application.ApplicationExit += delegate { Cleanup(); };
        }

        private ContextMenuStrip BuildMenu()
        {
            var m = new ContextMenuStrip();

            toggleItem = new ToolStripMenuItem("Dim background windows");
            toggleItem.Checked = settings.Enabled;
            toggleItem.Click += delegate { ToggleEnabled(); };
            m.Items.Add(toggleItem);
            m.Items.Add(new ToolStripSeparator());

            var header = new ToolStripLabel("Intensity");
            header.ForeColor = SystemColors.GrayText;
            m.Items.Add(header);

            slider = new TrackBar();
            slider.Minimum = 0; slider.Maximum = 100;
            slider.TickStyle = TickStyle.None;
            slider.Width = 180;
            slider.Value = (int)Math.Round(settings.Intensity * 100);
            slider.ValueChanged += delegate
            {
                settings.SetIntensity(slider.Value / 100.0);
            };
            var host = new ToolStripControlHost(slider);
            host.AutoSize = false;
            host.Width = 190;
            m.Items.Add(host);

            percentLabel = new ToolStripLabel(PercentText());
            percentLabel.ForeColor = SystemColors.GrayText;
            m.Items.Add(percentLabel);

            m.Items.Add(new ToolStripSeparator());

            var settingsItem = new ToolStripMenuItem("Settings…");
            settingsItem.Click += delegate { ShowSettings(); };
            m.Items.Add(settingsItem);

            var about = new ToolStripMenuItem("About OpenHaze");
            about.Click += delegate
            {
                MessageBox.Show(
                    "OpenHaze for Windows 1.0\n\n" +
                    "Dims background windows so you can focus on the one that matters.\n\n" +
                    "A personal, open-source recreation of HazeOver (hazeover.com) —\n" +
                    "if you love the idea, support the original on the Mac.\n\n" +
                    "Tray: double-click toggles, scroll wheel adjusts intensity.",
                    "About OpenHaze", MessageBoxButtons.OK, MessageBoxIcon.Information);
            };
            m.Items.Add(about);

            m.Items.Add(new ToolStripSeparator());
            var exit = new ToolStripMenuItem("Exit");
            exit.Click += delegate { ExitThread(); };
            m.Items.Add(exit);

            m.Opening += delegate
            {
                toggleItem.Checked = settings.Enabled;
                int v = (int)Math.Round(settings.Intensity * 100);
                if (slider.Value != v) slider.Value = v;
                percentLabel.Text = PercentText();
            };
            return m;
        }

        private string PercentText()
        {
            return string.Format("{0}%", (int)Math.Round(settings.Intensity * 100));
        }

        private void OnTrayMouseUp(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                // NotifyIcon only auto-shows the menu on right-click; mirror it for left.
                var mi = typeof(NotifyIcon).GetMethod("ShowContextMenu",
                    BindingFlags.Instance | BindingFlags.NonPublic);
                if (mi != null) mi.Invoke(tray, null);
                else menu.Show(Cursor.Position);
            }
        }

        private void ToggleEnabled()
        {
            settings.Enabled = !settings.Enabled;
            settings.NotifyChanged();
        }

        private void OnSettingsChanged()
        {
            tray.Icon = TrayIconRenderer.Make(settings.Enabled);
            if (percentLabel != null) percentLabel.Text = PercentText();
        }

        private void ShowSettings()
        {
            if (settingsForm == null || settingsForm.IsDisposed)
                settingsForm = new SettingsForm(settings, ReRegisterHotkeys);
            settingsForm.Show();
            settingsForm.Activate();
        }

        // ---- hotkeys ----

        private void ReRegisterHotkeys()
        {
            hotkeys.UnregisterAll();
            if (settings.ToggleVk != 0) hotkeys.Register(1, settings.ToggleMods, settings.ToggleVk);
            if (settings.IncVk != 0) hotkeys.Register(2, settings.IncMods, settings.IncVk);
            if (settings.DecVk != 0) hotkeys.Register(3, settings.DecMods, settings.DecVk);
        }

        private void OnHotkey(int id)
        {
            if (id == 1) ToggleEnabled();
            else if (id == 2) settings.SetIntensity(settings.Intensity + 0.10);
            else if (id == 3) settings.SetIntensity(settings.Intensity - 0.10);
        }

        // ---- scroll over the tray icon adjusts intensity ----

        private IntPtr MouseHookProc(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && wParam == (IntPtr)Native.WM_MOUSEWHEEL)
            {
                var data = (Native.MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(Native.MSLLHOOKSTRUCT));
                Native.RECT rect;
                if (TryGetTrayIconRect(out rect) &&
                    data.pt.X >= rect.Left && data.pt.X <= rect.Right &&
                    data.pt.Y >= rect.Top && data.pt.Y <= rect.Bottom)
                {
                    short delta = (short)((data.mouseData >> 16) & 0xFFFF);
                    double change = (delta / 120.0) * 0.05;   // 5% per notch
                    // Hop to the UI thread; the hook must return fast.
                    ui.Post(delegate { settings.SetIntensity(settings.Intensity + change); }, null);
                    return (IntPtr)1;   // swallow
                }
            }
            return Native.CallNextHookEx(mouseHook, nCode, wParam, lParam);
        }

        private bool TryGetTrayIconRect(out Native.RECT rect)
        {
            rect = new Native.RECT();
            try
            {
                var windowField = typeof(NotifyIcon).GetField("window", BindingFlags.Instance | BindingFlags.NonPublic);
                var idField = typeof(NotifyIcon).GetField("id", BindingFlags.Instance | BindingFlags.NonPublic);
                if (windowField == null || idField == null) return false;
                var nativeWindow = (NativeWindow)windowField.GetValue(tray);
                uint id = Convert.ToUInt32(idField.GetValue(tray));
                var ident = new Native.NOTIFYICONIDENTIFIER
                {
                    cbSize = (uint)Marshal.SizeOf(typeof(Native.NOTIFYICONIDENTIFIER)),
                    hWnd = nativeWindow.Handle,
                    uID = id,
                };
                return Native.Shell_NotifyIconGetRect(ref ident, out rect) == 0;
            }
            catch { return false; }
        }

        private void Cleanup()
        {
            if (mouseHook != IntPtr.Zero) { Native.UnhookWindowsHookEx(mouseHook); mouseHook = IntPtr.Zero; }
            hotkeys.UnregisterAll();
            tray.Visible = false;
            tray.Dispose();
            engine.Dispose();
        }

        protected override void ExitThreadCore()
        {
            Cleanup();
            base.ExitThreadCore();
        }
    }

    // Message-only window that owns the RegisterHotKey registrations.
    internal class HotkeyWindow : NativeWindow
    {
        private readonly Action<int> onHotkey;
        private readonly List<int> registered = new List<int>();

        public HotkeyWindow(Action<int> onHotkey)
        {
            this.onHotkey = onHotkey;
            CreateHandle(new CreateParams());
        }

        public void Register(int id, uint mods, uint vk)
        {
            if (Native.RegisterHotKey(Handle, id, mods, vk)) registered.Add(id);
        }

        public void UnregisterAll()
        {
            foreach (int id in registered) Native.UnregisterHotKey(Handle, id);
            registered.Clear();
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == Native.WM_HOTKEY) onHotkey(m.WParam.ToInt32());
            base.WndProc(ref m);
        }
    }

    // Draws the tray icon at runtime: a dimmed back window + bright front window.
    internal static class TrayIconRenderer
    {
        public static Icon Make(bool enabled)
        {
            using (var bmp = new Bitmap(32, 32))
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);

                using (var dim = new SolidBrush(Color.FromArgb(255, 96, 96, 104)))
                using (var bright = new SolidBrush(enabled
                    ? Color.FromArgb(255, 255, 196, 92)
                    : Color.FromArgb(255, 168, 168, 176)))
                using (var outline = new Pen(Color.FromArgb(90, 0, 0, 0), 1f))
                {
                    g.FillRectangle(dim, 4, 3, 20, 15);
                    g.DrawRectangle(outline, 4, 3, 20, 15);
                    g.FillRectangle(bright, 10, 12, 20, 16);
                    g.DrawRectangle(outline, 10, 12, 20, 16);
                }
                IntPtr hIcon = bmp.GetHicon();
                try
                {
                    using (var tmp = Icon.FromHandle(hIcon))
                    {
                        return (Icon)tmp.Clone();   // clone owns its own handle
                    }
                }
                finally
                {
                    Native.DestroyIcon(hIcon);
                }
            }
        }
    }
}
