const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");
const Ruler = @import("ruler.zig");
const Guide = @import("guide.zig");

const WM_TRAY = win.WM_USER + 0x01;
pub const WM_BRING_TO_FRONT = win.WM_USER + 0x02;

pub var control_pressed: bool = false;
pub var running: bool = false;
pub var rulers: std.ArrayList(*Ruler) = undefined;
pub var display_mode: enum { none, absolute, relative, invalid } = .none;

var allocator: std.mem.Allocator = undefined;
var hook: ?win.HHOOK = null;
var v_guides: std.ArrayList(*Guide) = undefined;
var h_guides: std.ArrayList(*Guide) = undefined;

var main_window: ?win.HWND = null;
var monitors: []win.MonitorInfo = undefined;
var nid: win.NOTIFYICONDATAA = undefined;
var tray_menu: ?win.HMENU = null;
var current_ruler: ?*Ruler = null;

var bitmap_cache: std.ArrayList(*gdip.CachedBitmap) = undefined;

// Menu item IDs
const ID_MODE_NO = 1001;
const ID_MODE_ABS = 1002;
const ID_MODE_REL = 1003;
const ID_CLEAR_GUIDES = 1004;
const ID_EXIT = 1005;

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    v_guides = .init(allocator);
    h_guides = .init(allocator);
    rulers = .init(allocator);
    bitmap_cache = .init(allocator);

    try gdip.startup();

    const hinstance = win.GetModuleHandleW(null) orelse return error.GetModuleHandleFailed;

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

    tray_menu = try createTrayMenu();
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
    if (tray_menu) |menu|
        _ = win.DestroyMenu(menu);
    if (main_window) |hwnd| {
        _ = win.Shell_NotifyIconA(win.NIM_DELETE, &nid);
        _ = win.DestroyWindow(hwnd);
    }
    allocator.free(monitors);
    v_guides.deinit();
    h_guides.deinit();
    for (bitmap_cache.items) |b| {
        b.deinit();
        allocator.destroy(b);
    }
    bitmap_cache.deinit();
    gdip.shutdown();
}

pub fn run() !void {
    while (running) {
        if (!processMessage())
            _ = win.WaitMessage();
    }
}

pub fn getMonitors() []const win.MonitorInfo {
    return monitors;
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
        win.WM_COMMAND => {
            const cmd_id = @as(u16, @truncate(wparam & 0xFFFF));
            switch (cmd_id) {
                ID_MODE_NO => display_mode = .none,
                ID_MODE_ABS => display_mode = .absolute,
                ID_MODE_REL => display_mode = .relative,
                ID_CLEAR_GUIDES => {
                    if (current_ruler) |ruler| {
                        removeGuides(ruler.monitor.rect, !ruler.vertical);
                        current_ruler = null;
                    } else {
                        removeAllGuides();
                    }
                },
                ID_EXIT => running = false,
                else => {},
            }
            notifyAll();
            return 0;
        },
        WM_TRAY => {
            switch (lparam) {
                win.WM_LBUTTONDOWN => bringToFrontAll(),
                win.WM_MBUTTONUP => {
                    running = false;
                    _ = win.PostMessageA(hwnd, WM_TRAY, 0, 0);
                },
                win.WM_RBUTTONDOWN => showPopupMenu(null),
                else => {},
            }
            return 0;
        },
        WM_BRING_TO_FRONT => {
            bringToFrontAll();
            return 0;
        },
        else => return win.DefWindowProcA(hwnd, msg, wparam, lparam),
    }
}

fn handleMonitorChange() !void {
    for (bitmap_cache.items) |b|
        b.deinit();
    bitmap_cache.clearRetainingCapacity();
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

pub fn removeGuides(monitor: win.RECT, vertical: bool) void {
    const guides = if (vertical) &v_guides else &h_guides;
    var i: usize = 0;
    while (i < guides.items.len) {
        const guide = guides.items[i];
        if (std.meta.eql(guide.bounds, monitor)) {
            _ = guides.swapRemove(i);
            guide.deinit();
        } else {
            i += 1;
        }
    }
}

pub fn bringToFrontAll() void {
    for (v_guides.items) |guide|
        _ = guide.bringToFront();
    for (h_guides.items) |guide|
        _ = guide.bringToFront();
    for (rulers.items) |ruler|
        _ = ruler.bringToFront();
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

fn createTrayMenu() !win.HMENU {
    const menu = win.CreatePopupMenu() orelse return error.CreateMenuFailed;
    _ = win.AppendMenuA(menu, win.MF_STRING, ID_MODE_NO, "No position");
    _ = win.AppendMenuA(menu, win.MF_STRING, ID_MODE_ABS, "Absolute position");
    _ = win.AppendMenuA(menu, win.MF_STRING, ID_MODE_REL, "Relative position");
    _ = win.AppendMenuA(menu, win.MF_SEPARATOR, 0, null);
    _ = win.AppendMenuA(menu, win.MF_STRING, ID_CLEAR_GUIDES, "Clear all guides");
    _ = win.AppendMenuA(menu, win.MF_SEPARATOR, 0, null);
    _ = win.AppendMenuA(menu, win.MF_STRING, ID_EXIT, "Exit");
    return menu;
}

pub fn showPopupMenu(ruler: ?*Ruler) void {
    current_ruler = ruler;
    const cursor_pos = win.getCursorPos() catch return;
    if (tray_menu) |menu| {
        const clear_text = if (ruler) |r| if (r.vertical) "Clear horizontal guides" else "Clear vertical guides" else "Clear all guides";
        var mii = std.mem.zeroInit(win.MENUITEMINFOA, .{
            .cbSize = @sizeOf(win.MENUITEMINFOA),
            .fMask = win.MIIM_STRING,
            .dwTypeData = @constCast(clear_text),
        });
        _ = win.SetMenuItemInfoA(menu, ID_CLEAR_GUIDES, 0, &mii);
        mii.fMask = win.MIIM_FTYPE | win.MIIM_STATE;
        mii.fType = win.MFT_RADIOCHECK;
        mii.fState = if (display_mode == .none) win.MFS_CHECKED else win.MFS_UNCHECKED;
        _ = win.SetMenuItemInfoA(menu, ID_MODE_NO, 0, &mii);
        mii.fState = if (display_mode == .absolute) win.MFS_CHECKED else win.MFS_UNCHECKED;
        _ = win.SetMenuItemInfoA(menu, ID_MODE_ABS, 0, &mii);
        mii.fState = if (display_mode == .relative) win.MFS_CHECKED else win.MFS_UNCHECKED;
        _ = win.SetMenuItemInfoA(menu, ID_MODE_REL, 0, &mii);

        const hwnd = main_window.?;
        _ = win.SetForegroundWindow(hwnd); // Required for proper menu behavior
        _ = win.TrackPopupMenu(menu, 0, cursor_pos.x, cursor_pos.y, 0, hwnd, null);
        _ = win.PostMessageA(hwnd, win.WM_NULL, 0, 0); // Post a message to ensure the menu closes properly
    }
}

pub fn getBuffer(width: i32, height: i32) !*gdip.CachedBitmap {
    for (bitmap_cache.items) |b|
        if (b.width == width and b.height == height)
            return b;
    const bitmap = try allocator.create(gdip.CachedBitmap);
    bitmap.* = try .init(width, height);
    try bitmap_cache.append(bitmap);
    return bitmap;
}
