# Send physical keyboard events to the owned Source window, including its real VGUI focus traversal.
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
public static class GarryCraftSourceInput {
    [StructLayout(LayoutKind.Sequential)] struct Keyboard { public ushort key, scan; public uint flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] struct Payload { [FieldOffset(0)] public Keyboard keyboard; [FieldOffset(0)] public Mouse mouse; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public uint type; public Payload payload; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int left, top, right, bottom; }
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr window, int command);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, IntPtr process);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint source, uint target, bool attach);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr window, uint flags);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern uint MapVirtualKey(uint key, uint mapping);
    static IntPtr target;
    static readonly HashSet<ushort> heldKeys = new HashSet<ushort>();
    static bool leftHeld, rightHeld;
    public static void Focus(IntPtr window) {
        if (window == IntPtr.Zero) throw new ArgumentException("The owned Source window handle is required.");
        if (target != window && (heldKeys.Count > 0 || leftHeld || rightHeld))
            throw new InvalidOperationException("Release the previous Source window's held input before changing targets.");
        target = window;
        ShowWindow(window, 9);
        uint current = GetCurrentThreadId();
        uint owner = GetWindowThreadProcessId(window, IntPtr.Zero);
        AttachThreadInput(current, owner, true);
        try { SetForegroundWindow(window); }
        finally { AttachThreadInput(current, owner, false); }
        Thread.Sleep(200);
        if (GetForegroundWindow() != target) {
            // Click the owned title bar when Windows denies programmatic foreground activation.
            SetWindowPos(target, new IntPtr(-1), 0, 0, 0, 0, 0x43);
            try {
                GetWindowRect(target, out Rect bounds);
                var point = new Point { x = (bounds.left + bounds.right) / 2, y = bounds.top + 10 };
                RequireTitleBar(point);
                SetCursorPos(point.x, point.y);
                ActivateTitleBar(point, 2);
                leftHeld = true;
                Thread.Sleep(60);
                ActivateTitleBar(point, 4);
                leftHeld = false;
                Thread.Sleep(200);
            } finally {
                SetWindowPos(target, new IntPtr(-2), 0, 0, 0, 0, 0x43);
            }
        }
        RequireFocus();
        GetClientRect(target, out Rect client);
        var center = new Point { x = (client.right - client.left) / 2, y = (client.bottom - client.top) / 2 };
        ClientToScreen(target, ref center);
        SetCursorPos(center.x, center.y);
    }
    static void RequireTitleBar(Point point) {
        if (GetAncestor(WindowFromPoint(point), 2) != target)
            throw new InvalidOperationException("The owned Source title bar is covered.");
    }
    // Foreground activation is the sole exception. Verify the exact owned title bar before each click event.
    static void ActivateTitleBar(Point point, uint flags) {
        RequireTitleBar(point);
        SetCursorPos(point.x, point.y);
        var input = new Input { type = 0, payload = new Payload { mouse = new Mouse { flags = flags } } };
        if (SendInput(1, new[] { input }, Marshal.SizeOf<Input>()) != 1)
            throw new InvalidOperationException("Windows did not accept the Source activation event.");
    }
    static void RequireFocus() {
        if (target == IntPtr.Zero || GetForegroundWindow() != target)
            throw new InvalidOperationException("The owned Source window must have keyboard focus.");
    }
    static void Dispatch(Input input) {
        RequireFocus();
        if (SendInput(1, new[] { input }, Marshal.SizeOf<Input>()) != 1)
            throw new InvalidOperationException("Windows did not accept the Source input event.");
    }
    public static void Key(ushort key) {
        KeyDown(key);
        Thread.Sleep(60);
        KeyUp(key);
        Thread.Sleep(120);
    }
    public static void KeyDown(ushort key) {
        Dispatch(KeyboardEvent(key, false));
        heldKeys.Add(key);
    }
    public static void KeyUp(ushort key) {
        Dispatch(KeyboardEvent(key, true));
        heldKeys.Remove(key);
    }
    // Physical scan codes reach Source world controls as well as its VGUI text widgets.
    static Input KeyboardEvent(ushort key, bool up) {
        uint scan = MapVirtualKey(key, 4);
        if (scan == 0) throw new ArgumentException("The key has no Windows scan code.");
        uint flags = 8u | (up ? 2u : 0u);
        if ((scan & 0xff00) == 0xe000) flags |= 1u;
        return new Input { type = 1, payload = new Payload { keyboard = new Keyboard { scan = (ushort)(scan & 0xff), flags = flags } } };
    }
    public static void Hold(ushort key, int milliseconds) {
        if (milliseconds < 0) throw new ArgumentOutOfRangeException(nameof(milliseconds));
        KeyDown(key);
        try { Thread.Sleep(milliseconds); }
        finally { if (GetForegroundWindow() == target) KeyUp(key); }
        RequireFocus();
    }
    static uint MouseFlag(string button, bool down) {
        if (button == "left") return down ? 2u : 4u;
        if (button == "right") return down ? 8u : 16u;
        throw new ArgumentException("The mouse button must be left or right.");
    }
    public static void MouseDown(string button) {
        Dispatch(new Input { type = 0, payload = new Payload { mouse = new Mouse { flags = MouseFlag(button, true) } } });
        if (button == "left") leftHeld = true; else rightHeld = true;
    }
    public static void MouseUp(string button) {
        Dispatch(new Input { type = 0, payload = new Payload { mouse = new Mouse { flags = MouseFlag(button, false) } } });
        if (button == "left") leftHeld = false; else rightHeld = false;
    }
    public static void Relative(int x, int y) {
        Dispatch(new Input { type = 0, payload = new Payload { mouse = new Mouse { x = x, y = y, flags = 1 } } });
    }
    // Use Windows wheel units: 120 is one wheel notch.
    public static void Wheel(int delta) {
        Dispatch(new Input { type = 0, payload = new Payload { mouse = new Mouse { data = unchecked((uint)delta), flags = 0x800 } } });
    }
    public static bool Release() {
        if (target == IntPtr.Zero || GetForegroundWindow() != target) return false;
        try {
            foreach (ushort key in new List<ushort>(heldKeys)) KeyUp(key);
            if (leftHeld) MouseUp("left");
            if (rightHeld) MouseUp("right");
            return true;
        } catch (InvalidOperationException) {
            if (GetForegroundWindow() != target) return false;
            throw;
        }
    }
    public static void Text(string text) {
        foreach (char character in text) {
            short mapping = VkKeyScan(character);
            if (mapping == -1) throw new InvalidOperationException("The test text has no keyboard mapping.");
            bool shift = (mapping & 0x100) != 0;
            if (shift) KeyDown(0x10);
            Key((ushort)(mapping & 0xff));
            if (shift) KeyUp(0x10);
        }
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern short VkKeyScan(char character);
    public static void Click(double x, double y) {
        RequireFocus();
        GetClientRect(target, out Rect rect);
        var point = new Point { x = (int)((rect.right - rect.left) * x), y = (int)((rect.bottom - rect.top) * y) };
        ClientToScreen(target, ref point);
        SetCursorPos(point.x, point.y);
        Thread.Sleep(100);
        MouseDown("left");
        Thread.Sleep(60);
        MouseUp("left");
        Thread.Sleep(200);
    }
}
'@
