const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");
const Ruler = @import("rulers.zig");
const Guide = @import("guide.zig");

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

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    v_guides = std.ArrayList(*Guide).init(allocator);
    h_guides = std.ArrayList(*Guide).init(allocator);
    rulers = std.ArrayList(*Ruler).init(allocator);

    try gdip.startup();

    const hinstance = win.GetModuleHandleW(null) orelse return error.GetModuleHandleFailed;

    size_h_cursor = win.LoadCursorA(null, win.IDC_SIZEWE);
    size_v_cursor = win.LoadCursorA(null, win.IDC_SIZENS);

    control_pressed = false;
    hook = win.SetWindowsHookExA(win.WH_KEYBOARD_LL, lowLevelKeyboardProc, hinstance, 0);
    running = true;

    // Enumerate monitors and create rulers for each
    const monitors = try win.enumMonitors(allocator);
    defer allocator.free(monitors);
    var first_ruler = true;
    for (monitors) |monitor| {
        try rulers.append(try Ruler.create(allocator, true, first_ruler, monitor));
        try rulers.append(try Ruler.create(allocator, false, false, monitor));
        first_ruler = false;
    }
    for (rulers.items) |ruler|
        ruler.base.show();
}

pub fn deinit() void {
    if (hook) |h|
        _ = win.UnhookWindowsHookEx(h);
    removeAllGuides();
    for (rulers.items) |ruler|
        ruler.deinit();
    rulers.deinit();
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

pub fn addGuide(guide: *Guide) !void {
    if (guide.vertical)
        try v_guides.append(guide)
    else
        try h_guides.append(guide);
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
