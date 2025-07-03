const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");
const Ruler = @import("ruler.zig");
const Guide = @import("guide.zig");

const WM_TRAY = win.WM_USER + 0x01;

pub var control_pressed: bool = false;
pub var running: bool = false;
pub var rulers: std.ArrayList(*Ruler) = undefined;
pub var display_mode: u32 = 0;

pub var size_h_cursor: ?win.HCURSOR = null;
pub var size_v_cursor: ?win.HCURSOR = null;

var allocator: std.mem.Allocator = undefined;
var hook: ?win.HHOOK = null;
var v_guides: std.ArrayList(*Guide) = undefined;
var h_guides: std.ArrayList(*Guide) = undefined;

var main_window: ?win.HWND = null;
var monitors: []win.MonitorInfo = undefined;
var nid: win.NOTIFYICONDATAA = undefined;

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    v_guides = std.ArrayList(*Guide).init(allocator);
    h_guides = std.ArrayList(*Guide).init(allocator);
    rulers = std.ArrayList(*Ruler).init(allocator);

    try gdip.startup();

    const hinstance = win.GetModuleHandleW(null) orelse return error.GetModuleHandleFailed;

    size_h_cursor = win.LoadCursorA(null, win.IDC_SIZEWE);
    size_v_cursor = win.LoadCursorA(null, win.IDC_SIZENS);

    hook = win.SetWindowsHookExA(win.WH_KEYBOARD_LL, lowLevelKeyboardProc, hinstance, 0);
    running = true;

    _ = win.RegisterClassA(&.{
        .style = 0,
        .lpfnWndProc = mainWndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinstance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "RulersWndCls",
    });
    main_window = win.CreateWindowExA(
        0,
        "RulersWndCls",
        "Rulers",
        0,
        0,
        0,
        0,
        0,
        null,
        null,
        hinstance,
        null,
    ) orelse return error.CreateWindowFailed;

    nid = std.mem.zeroInit(win.NOTIFYICONDATAA, .{
        .cbSize = @sizeOf(win.NOTIFYICONDATAA),
        .hWnd = main_window.?,
        .hIcon = win.LoadIconA(hinstance, "MAINICON") orelse return,
        .uFlags = win.NIF_ICON | win.NIF_TIP | win.NIF_MESSAGE,
        .uCallbackMessage = WM_TRAY,
    });
    const tip = "Rulers";
    @memcpy(nid.szTip[0..tip.len], tip);
    nid.szTip[tip.len] = 0;
    _ = win.Shell_NotifyIconA(win.NIM_ADD, &nid);

    monitors = try alloc.alloc(win.MonitorInfo, 0);
    try handleMonitorChange();
}

pub fn deinit() void {
    if (hook) |h|
        _ = win.UnhookWindowsHookEx(h);
    removeAllGuides();
    for (rulers.items) |ruler|
        ruler.deinit();
    rulers.deinit();
    if (main_window) |hwnd| {
        _ = win.Shell_NotifyIconA(win.NIM_DELETE, &nid);
        _ = win.DestroyWindow(hwnd);
    }
    allocator.free(monitors);
    v_guides.deinit();
    h_guides.deinit();
    gdip.shutdown();
}

pub fn run() !void {
    while (running) {
        if (!processMessage())
            _ = win.WaitMessage();
    }
}

fn processMessage() bool {
    var msg: win.MSG = undefined;
    if (win.PeekMessageA(&msg, null, 0, 0, win.PM_REMOVE) != 0) {
        if (msg.message != win.WM_QUIT) {
            _ = win.TranslateMessage(&msg);
            _ = win.DispatchMessageA(&msg);
        } else {
            running = false;
        }
        return true;
    }
    return false;
}

fn lowLevelKeyboardProc(nCode: c_int, wParam: win.WPARAM, lParam: win.LPARAM) callconv(.C) win.LRESULT {
    const pkb: *win.KBDLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lParam)));
    if (pkb.vkCode == win.VK_LCONTROL) {
        const new_control_state = (wParam == win.WM_KEYDOWN);
        if (control_pressed != new_control_state) {
            control_pressed = new_control_state;
            notifyAll();
        }
    }
    return win.CallNextHookEx(hook, nCode, wParam, lParam);
}

fn mainWndProc(hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) callconv(.C) win.LRESULT {
    switch (msg) {
        win.WM_DISPLAYCHANGE => {
            handleMonitorChange() catch {};
            return 0;
        },
        WM_TRAY => {
            switch (lparam) {
                win.WM_LBUTTONDOWN => bringToFrontAll(),
                win.WM_MBUTTONUP => {
                    running = false;
                    _ = win.PostMessageA(hwnd, WM_TRAY, 0, 0);
                },
                win.WM_RBUTTONDOWN => {
                    display_mode += 1;
                    display_mode %= 3;
                    notifyAll();
                },
                else => {},
            }
            return 0;
        },
        else => return win.DefWindowProcA(hwnd, msg, wparam, lparam),
    }
}

fn handleMonitorChange() !void {
    const new_monitors = try win.enumMonitors(allocator);
    defer allocator.free(new_monitors);
    if (monitorsEqual(monitors, new_monitors))
        return;
    for (rulers.items) |ruler|
        ruler.deinit();
    rulers.clearRetainingCapacity();
    allocator.free(monitors);
    monitors = try allocator.dupe(win.MonitorInfo, new_monitors);
    for (monitors) |monitor| {
        try rulers.append(try Ruler.create(allocator, true, monitor));
        try rulers.append(try Ruler.create(allocator, false, monitor));
    }
    for (rulers.items) |ruler|
        ruler.base.show();
    updateGuides(&v_guides);
    updateGuides(&h_guides);
}

fn monitorsEqual(a: []const win.MonitorInfo, b: []const win.MonitorInfo) bool {
    if (a.len != b.len) return false;
    for (a) |ma| {
        var found = false;
        for (b) |mb| {
            if (std.meta.eql(ma.rect, mb.rect) and ma.is_primary == mb.is_primary) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

fn updateGuides(guides: *std.ArrayList(*Guide)) void {
    var i: usize = 0;
    while (i < guides.items.len) {
        if (!updateGuideBounds(guides.items[i]))
            guides.swapRemove(i).deinit()
        else
            i += 1;
    }
}

fn updateGuideBounds(g: *Guide) bool {
    for (monitors) |m| {
        const left, const top, const right, const bottom = .{ m.rect.left, m.rect.top, m.rect.right, m.rect.bottom };
        const found = if (g.vertical)
            g.base.left >= left and g.base.left < right and g.base.top < bottom and g.base.top + g.base.height >= top
        else
            g.base.top >= top and g.base.top < bottom and g.base.left < right and g.base.left + g.base.width >= left;
        if (found) {
            g.setBounds(m.rect) catch break;
            return true;
        }
    }
    return false;
}

pub fn addGuide(guide: *Guide) !void {
    const guides = if (guide.vertical) &v_guides else &h_guides;
    try guides.append(guide);
    guide.base.show();
}

pub fn removeGuide(guide: *Guide) void {
    const guides = if (guide.vertical) &v_guides else &h_guides;
    for (guides.items, 0..) |g, i| {
        if (g == guide) {
            _ = guides.swapRemove(i);
            guide.deinit();
            break;
        }
    }
}

pub fn removeAllGuides() void {
    for (v_guides.items) |guide|
        guide.deinit();
    v_guides.clearRetainingCapacity();
    for (h_guides.items) |guide|
        guide.deinit();
    h_guides.clearRetainingCapacity();
}

pub fn bringToFrontAll() void {
    for (v_guides.items) |guide|
        _ = win.SetForegroundWindow(guide.base.hwnd.?);
    for (h_guides.items) |guide|
        _ = win.SetForegroundWindow(guide.base.hwnd.?);
    for (rulers.items) |ruler|
        _ = win.SetForegroundWindow(ruler.base.hwnd.?);
}

pub fn notifyAll() void {
    for (v_guides.items) |guide|
        guide.notify();
    for (h_guides.items) |guide|
        guide.notify();
}

pub fn dumpGuides(content: *std.ArrayList(u8)) !void {
    for (h_guides.items, 0..) |guide, i|
        try content.writer().print("H{}={}\n", .{ i, guide.base.top });
    for (v_guides.items, 0..) |guide, i|
        try content.writer().print("V{}={}\n", .{ i, guide.base.left });
}

pub fn getDistance(guide: *Guide) i32 {
    var result: i32 = -2;
    const guides = if (guide.vertical) &v_guides else &h_guides;
    for (guides.items) |g| {
        if (!guidesOnSameMonitor(guide, g)) continue;
        const pos = if (guide.vertical) g.base.left else g.base.top;
        const guide_pos = if (guide.vertical) guide.base.left else guide.base.top;
        if (pos < guide_pos and pos > result)
            result = pos;
    }
    return result;
}

fn guidesOnSameMonitor(guide1: *Guide, guide2: *Guide) bool {
    return guide1.bounds.left == guide2.bounds.left and
        guide1.bounds.top == guide2.bounds.top;
}
