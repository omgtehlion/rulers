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
const GUIDE_CREATION_MARGIN = 20;
const GUIDE_CREATION_MIN = 18;
const GUIDE_OFFSET = 7;

const Self = @This();

base: AlphaWnd,
nid: win.NOTIFYICONDATAA = undefined,
current_guide: ?*Guide = null,
allocator: std.mem.Allocator,

pub fn create(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);
    self.allocator = allocator;
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

    const rect = try win.getWindowRect(win.GetDesktopWindow());
    self.base.width = rect.right;
    self.base.height = rect.bottom;
    self.base.left = 0;
    self.base.top = 0;
    try self.createRulers();
    self.setupTray();
    return self;
}

pub fn deinit(self: *Self) void {
    _ = win.Shell_NotifyIconA(win.NIM_DELETE, &self.nid);
    self.base.deinit();
    self.allocator.destroy(self);
}

fn createRulers(self: *Self) !void {
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

    // Clear background
    try gdip.graphicsClear(graphics, 0);

    // Draw ruler backgrounds
    try gdip.fillRectangleI(graphics, white_brush, 0, 0, RULER_WIDTH, self.base.height);
    try gdip.fillRectangleI(graphics, white_brush, 0, 0, self.base.width, RULER_WIDTH);

    // Draw ruler borders
    try gdip.drawLineI(graphics, black_pen, RULER_WIDTH - 1, RULER_WIDTH, RULER_WIDTH - 1, self.base.height);
    try gdip.drawLineI(graphics, black_pen, RULER_WIDTH, RULER_WIDTH - 1, self.base.width, RULER_WIDTH - 1);

    var string_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&string_buffer);
    const local_allocator = fba.allocator();

    // Draw vertical ruler markings
    var y: i32 = 0;
    while (y <= self.base.height) : (y += MAJOR_TICK) {
        // Draw major tick
        try gdip.drawLineI(graphics, black_pen, 0, y, RULER_WIDTH - 1, y);
        fba.reset();
        const num_str = std.fmt.allocPrint(local_allocator, "{}", .{y}) catch continue;
        // Draw each digit vertically
        var digit_y = y - FONT_SIZE + LABEL_Y_OFFSET;
        for (num_str) |char| {
            gdip.drawString(
                graphics,
                &[_:0]u16{ char, 0 },
                -1,
                font,
                &gdip.makeRect(0, @floatFromInt(digit_y), RULER_WIDTH - 1, FONT_SIZE * 1.5),
                null,
                black_brush,
            ) catch {};
            digit_y += FONT_SIZE;
        }
    }

    // Draw vertical minor ticks
    y = 0;
    while (y <= self.base.height) : (y += MINOR_TICK) {
        const l: c_int = if (@mod(@divTrunc(y, MINOR_TICK), 2) == 1) MINOR_TICK_LONG else MINOR_TICK_SHORT;
        try gdip.drawLineI(graphics, black_pen, RULER_WIDTH - l, y, RULER_WIDTH - 1, y);
    }

    // Draw horizontal ruler markings
    var x: i32 = 0;
    while (x <= self.base.width) : (x += MAJOR_TICK) {
        // Draw major tick
        try gdip.drawLineI(graphics, black_pen, x, 0, x, RULER_WIDTH - 1);
        fba.reset();
        const num_str = std.fmt.allocPrint(local_allocator, "{}", .{x}) catch continue;
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

    // Draw horizontal minor ticks
    x = 0;
    while (x <= self.base.width) : (x += MINOR_TICK) {
        const l: c_int = if (@mod(@divTrunc(x, MINOR_TICK), 2) == 1) MINOR_TICK_LONG else MINOR_TICK_SHORT;
        try gdip.drawLineI(graphics, black_pen, x, RULER_WIDTH - l, x, RULER_WIDTH - 1);
    }

    // Draw corner square
    try gdip.fillRectangleI(graphics, white_brush, 0, 0, RULER_WIDTH, RULER_WIDTH);

    self.base.redraw();
    self.base.invalidate();
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
    if (p.x < GUIDE_CREATION_MARGIN and p.y > GUIDE_CREATION_MIN) {
        _ = win.SetCursor(globals.size_h_cursor);
        self.current_guide = Guide.create(self.allocator, true, self.base.height) catch return;
        self.current_guide.?.move(p.x - GUIDE_OFFSET);
    } else if (p.y < GUIDE_CREATION_MARGIN and p.x > GUIDE_CREATION_MIN) {
        _ = win.SetCursor(globals.size_v_cursor);
        self.current_guide = Guide.create(self.allocator, false, self.base.width) catch return;
        self.current_guide.?.move(p.y - GUIDE_OFFSET);
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
            if (self.current_guide) |guide|
                guide.move(if (guide.vertical) rect.left + guide.base.left else rect.top + guide.base.top);
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
