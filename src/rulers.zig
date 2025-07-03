const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");
const AlphaWnd = @import("alpha_wnd.zig");
const Guide = @import("guide.zig");
const globals = @import("globals.zig");

const WM_TRAY = win.WM_USER + 0x01;

const RULER_WIDTH = 16;
const MAJOR_TICK = 50;
const MINOR_TICK = 5;
const MINOR_TICK_SHORT = 4;
const MINOR_TICK_LONG = 6;
const FONT_SIZE = 11;
const LABEL_Y_OFFSET = -2;

const Self = @This();

base: AlphaWnd,
nid: win.NOTIFYICONDATAA = undefined,
current_guide: ?*Guide = null,
allocator: std.mem.Allocator,
vertical: bool,
has_tray: bool,
monitor: win.MonitorInfo,

pub fn create(allocator: std.mem.Allocator, vertical: bool, has_tray: bool, monitor: win.MonitorInfo) !*Self {
    const self = try allocator.create(Self);
    self.allocator = allocator;
    self.vertical = vertical;
    self.has_tray = has_tray;
    self.monitor = monitor;
    try AlphaWnd.createAt(
        &self.base,
        win.CS_DBLCLKS,
        win.WS_POPUP,
        win.WS_EX_TOOLWINDOW,
        null,
        "Rulers Window",
        "TRulersWndClass",
        null,
        null,
    );
    self.base.processMsg = processMsg;
    self.base.width = if (vertical) RULER_WIDTH else monitor.rect.right - monitor.rect.left;
    self.base.height = if (!vertical) RULER_WIDTH else monitor.rect.bottom - monitor.rect.top;
    self.base.left = monitor.rect.left;
    self.base.top = monitor.rect.top;
    try self.createRuler();
    if (has_tray)
        self.setupTray();
    return self;
}

pub fn deinit(self: *Self) void {
    if (self.has_tray)
        _ = win.Shell_NotifyIconA(win.NIM_DELETE, &self.nid);
    self.base.deinit();
    self.allocator.destroy(self);
}

fn createRuler(self: *Self) !void {
    self.base.bitmap = try gdip.createBitmapFromScan0(
        self.base.width,
        self.base.height,
        0,
        gdip.PixelFormat32bppARGB,
        null,
    );
    defer gdip.disposeImage(@ptrCast(self.base.bitmap.?)) catch {};

    const graphics = try gdip.createGraphicsFromImage(@ptrCast(self.base.bitmap.?));
    defer gdip.deleteGraphics(graphics) catch {};

    try gdip.setTextRenderingHint(graphics, .TextRenderingHintSystemDefault);

    // Create brushes and pens
    const white_brush = try gdip.createSolidFill(gdip.makeColor(255, 255, 255, 255));
    defer gdip.deleteBrush(white_brush) catch {};

    const black_brush = try gdip.createSolidFill(gdip.makeColor(255, 0, 0, 0));
    defer gdip.deleteBrush(black_brush) catch {};

    const black_pen = try gdip.createPen1(gdip.makeColor(255, 0, 0, 0), 1.0, .UnitPixel);
    defer gdip.deletePen(black_pen) catch {};

    // Create font
    const font_family = try gdip.createFontFamilyFromName(std.unicode.utf8ToUtf16LeStringLiteral("Segoe UI"), null);
    defer gdip.deleteFontFamily(font_family) catch {};

    const font = try gdip.createFont(font_family, FONT_SIZE, .FontStyleRegular, .UnitPixel);
    defer gdip.deleteFont(font) catch {};

    var string_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&string_buffer);
    const local_allocator = fba.allocator();

    try gdip.graphicsClear(graphics, gdip.makeColor(255, 255, 255, 255));
    if (self.vertical) {
        try gdip.drawLineI(graphics, black_pen, RULER_WIDTH - 1, RULER_WIDTH - 1, RULER_WIDTH - 1, self.base.height);
        // Draw vertical ruler markings
        var screen_y = @divFloor(self.base.top, MAJOR_TICK) * MAJOR_TICK;
        while (screen_y <= self.base.top + self.base.height) : (screen_y += MAJOR_TICK) {
            const y = screen_y - self.base.top;
            if (y < RULER_WIDTH)
                continue;
            try gdip.drawLineI(graphics, black_pen, 0, y, RULER_WIDTH - 1, y);
            fba.reset();
            const num_str = std.fmt.allocPrint(local_allocator, "{}", .{screen_y}) catch continue;
            // Draw each digit vertically
            var digit_y = y - FONT_SIZE + LABEL_Y_OFFSET;
            for (num_str) |char| {
                if (digit_y >= 0 and digit_y < self.base.height) {
                    gdip.drawString(
                        graphics,
                        &[_:0]u16{ char, 0 },
                        -1,
                        font,
                        &gdip.makeRect(0, @floatFromInt(digit_y), RULER_WIDTH - 1, FONT_SIZE * 1.5),
                        null,
                        black_brush,
                    ) catch {};
                }
                digit_y += FONT_SIZE;
            }
        }

        // Draw vertical minor ticks
        screen_y = @divFloor(self.base.top, MINOR_TICK) * MINOR_TICK;
        while (screen_y <= self.base.top + self.base.height) : (screen_y += MINOR_TICK) {
            const y = screen_y - self.base.top;
            if (y < RULER_WIDTH)
                continue;
            const tick_index = @divTrunc(screen_y, MINOR_TICK);
            const l: c_int = if (@mod(tick_index, 2) == 1) MINOR_TICK_LONG else MINOR_TICK_SHORT;
            try gdip.drawLineI(graphics, black_pen, RULER_WIDTH - l, y, RULER_WIDTH - 1, y);
        }
    } else {
        try gdip.drawLineI(graphics, black_pen, RULER_WIDTH - 1, RULER_WIDTH - 1, self.base.width, RULER_WIDTH - 1);
        // Draw horizontal ruler markings
        var screen_x = @divFloor(self.base.left, MAJOR_TICK) * MAJOR_TICK;
        while (screen_x <= self.base.left + self.base.width) : (screen_x += MAJOR_TICK) {
            const x = screen_x - self.base.left;
            if (x < RULER_WIDTH)
                continue;
            if (x >= 0 and x <= self.base.width) {
                try gdip.drawLineI(graphics, black_pen, x, 0, x, RULER_WIDTH - 1);
                fba.reset();
                const num_str = std.fmt.allocPrint(local_allocator, "{}", .{screen_x}) catch continue;
                const utf16_str = std.unicode.utf8ToUtf16LeAllocZ(local_allocator, num_str) catch continue;
                gdip.drawString(
                    graphics,
                    utf16_str,
                    -1,
                    font,
                    &gdip.makeRect(@floatFromInt(x), LABEL_Y_OFFSET, MAJOR_TICK, RULER_WIDTH - 1),
                    null,
                    black_brush,
                ) catch {};
            }
        }
        // Draw horizontal minor ticks
        screen_x = @divFloor(self.base.left, MINOR_TICK) * MINOR_TICK;
        while (screen_x <= self.base.left + self.base.width) : (screen_x += MINOR_TICK) {
            const x = screen_x - self.base.left;
            if (x < RULER_WIDTH)
                continue;
            const tick_index = @divTrunc(screen_x, MINOR_TICK);
            const l: c_int = if (@mod(tick_index, 2) == 1) MINOR_TICK_LONG else MINOR_TICK_SHORT;
            try gdip.drawLineI(graphics, black_pen, x, RULER_WIDTH - l, x, RULER_WIDTH - 1);
        }
    }
    self.base.redraw();
}

fn setupTray(self: *Self) void {
    const hinstance = win.GetModuleHandleW(null);
    self.nid = std.mem.zeroInit(win.NOTIFYICONDATAA, .{
        .cbSize = @sizeOf(win.NOTIFYICONDATAA),
        .hWnd = self.base.hwnd.?,
        .hIcon = win.LoadIconA(hinstance, "MAINICON") orelse return,
        .uFlags = win.NIF_ICON | win.NIF_TIP | win.NIF_MESSAGE,
        .uCallbackMessage = WM_TRAY,
    });
    const tip = "Rulers";
    @memcpy(self.nid.szTip[0..tip.len], tip);
    self.nid.szTip[tip.len] = 0;
    _ = win.Shell_NotifyIconA(win.NIM_ADD, &self.nid);
}

fn createNew(self: *Self) void {
    const p = win.getCursorPos() catch return;
    if (self.vertical) {
        if (p.y > self.base.top + RULER_WIDTH) {
            _ = win.SetCursor(globals.size_h_cursor);
            self.current_guide = Guide.create(self.allocator, true, self.monitor.rect) catch return; // true = vertical guide
        }
    } else {
        if (p.x > self.base.left + RULER_WIDTH) {
            _ = win.SetCursor(globals.size_v_cursor);
            self.current_guide = Guide.create(self.allocator, false, self.monitor.rect) catch return; // false = horizontal guide
        }
    }
}

fn processMsg(base: *AlphaWnd, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) ?win.LRESULT {
    _ = wparam;
    const self: *Self = @fieldParentPtr("base", base);
    switch (msg) {
        win.WM_NCHITTEST => return win.HTCAPTION,
        win.WM_ENTERSIZEMOVE => {
            self.createNew();
            return 0;
        },
        win.WM_EXITSIZEMOVE => {
            if (self.current_guide) |guide|
                _ = win.PostMessageA(guide.base.hwnd, win.WM_EXITSIZEMOVE, 0, 0);
            self.current_guide = null;
            return 0;
        },
        win.WM_MOVING => {
            const rect: *win.RECT = @ptrFromInt(@as(usize, @bitCast(lparam)));
            if (self.current_guide) |guide| {
                const cursor_pos = win.getCursorPos() catch return 0;
                const guide_pos = (if (guide.vertical) cursor_pos.x else cursor_pos.y);
                guide.move(guide_pos - 2);
            }
            rect.* = .{
                .top = self.base.top,
                .bottom = self.base.top + self.base.height,
                .left = self.base.left,
                .right = self.base.left + self.base.width,
            };
            return 0;
        },
        win.WM_CLOSE, win.WM_NCMBUTTONUP => {
            globals.running = false;
            return 0;
        },
        win.WM_NCRBUTTONDOWN => {
            if (globals.control_pressed)
                globals.removeAllGuides();
            return 0;
        },
        win.WM_SETCURSOR => {
            _ = win.SetCursor(win.LoadCursorA(null, win.IDC_ARROW) orelse null);
            return 0;
        },
        WM_TRAY => {
            if (!self.has_tray) return null;
            switch (lparam) {
                win.WM_MOUSEMOVE => {},
                win.WM_LBUTTONDOWN => globals.bringToFrontAll(),
                win.WM_MBUTTONUP => {
                    globals.running = false;
                    _ = win.PostMessageA(self.base.hwnd, WM_TRAY, 0, 0);
                },
                win.WM_RBUTTONDOWN => {
                    globals.display_mode += 1;
                    globals.display_mode %= 3;
                    globals.notifyAll();
                },
                else => {},
            }
            return 0;
        },
        else => return null,
    }
}
