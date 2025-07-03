const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");
const AlphaWnd = @import("alpha_wnd.zig");
const Guide = @import("guide.zig");
const globals = @import("globals.zig");

const WM_TRAY = win.WM_USER + 0x01;
const FRAME_THICKNESS = 25;

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
    const white_pen = try gdip.createPen1(gdip.makeColor(255, 255, 255, 255), 1.0, .UnitPixel);
    defer gdip.deletePen(white_pen) catch {};

    // Create font
    const font_family = try gdip.createFontFamilyFromName(std.unicode.utf8ToUtf16LeStringLiteral("Arial"), null);
    defer gdip.deleteFontFamily(font_family) catch {};

    const font = try gdip.createFont(font_family, 9, .FontStyleRegular, .UnitPixel);
    defer gdip.deleteFont(font) catch {};

    // Clear background
    try gdip.graphicsClear(graphics, 0);

    // Draw ruler backgrounds
    try gdip.fillRectangleI(graphics, white_brush, 0, 0, 15, self.base.height);
    try gdip.fillRectangleI(graphics, white_brush, 0, 0, self.base.width, 15);

    // Draw ruler borders
    try gdip.drawLineI(graphics, black_pen, 15, 16, 15, self.base.height);
    try gdip.drawLineI(graphics, black_pen, 16, 15, self.base.width, 15);

    // Draw vertical ruler markings
    var i: i32 = 0;
    while (i <= @divFloor(self.base.height, 50)) : (i += 1) {
        const y = i * 50;
        // Draw major tick and number
        try gdip.drawLineI(graphics, black_pen, 0, y, 15, y);

        const num_str = std.fmt.allocPrint(std.heap.page_allocator, "{}", .{i * 50}) catch continue;
        defer std.heap.page_allocator.free(num_str);

        // Draw each digit vertically
        for (num_str, 0..) |char, j| {
            const char_str = [_]u8{ char, 0 };
            const utf16_char = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, char_str[0..1]) catch continue;
            defer std.heap.page_allocator.free(utf16_char);

            gdip.drawString(
                graphics,
                utf16_char,
                -1,
                font,
                &gdip.makeRect(0, @floatFromInt(y + @as(i32, @intCast(j)) * 9 - 8), 15, 12),
                null,
                black_brush,
            ) catch {};
        }
    }

    // Draw vertical minor ticks
    i = 0;
    while (i <= @divFloor(self.base.height, 5)) : (i += 1) {
        const y = i * 5;
        const x: c_int = if (@mod(i, 2) == 1) 11 else 9;
        try gdip.drawLineI(graphics, black_pen, x, y, 15, y);
    }

    // Draw horizontal ruler markings
    i = 0;
    while (i <= @divFloor(self.base.width, 50)) : (i += 1) {
        const x = i * 50;

        // Draw major tick and number
        try gdip.drawLineI(graphics, black_pen, x, 0, x, 15);

        const num_str = std.fmt.allocPrint(std.heap.page_allocator, "{}", .{i * 50}) catch continue;
        defer std.heap.page_allocator.free(num_str);

        const utf16_str = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, num_str) catch continue;
        defer std.heap.page_allocator.free(utf16_str);

        gdip.drawString(
            graphics,
            utf16_str,
            -1,
            font,
            &gdip.makeRect(@floatFromInt(x), 0, 50, 15),
            null,
            black_brush,
        ) catch {};
    }

    // Draw horizontal minor ticks
    i = 0;
    while (i <= @divFloor(self.base.width, 5)) : (i += 1) {
        const x = i * 5;
        const y: c_int = if (@mod(i, 2) == 1) 11 else 9;
        try gdip.drawLineI(graphics, black_pen, x, y, x, 15);
    }

    // Draw corner square
    try gdip.fillRectangleI(graphics, white_brush, 0, 0, 16, 16);

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
    if (p.x < 20 and p.y > 18) {
        _ = win.SetCursor(globals.size_h_cursor);
        self.current_guide = Guide.create(self.allocator, true, self.base.height) catch return;
        self.current_guide.?.move(p.x - 7);
    } else if (p.y < 20 and p.x > 18) {
        _ = win.SetCursor(globals.size_v_cursor);
        self.current_guide = Guide.create(self.allocator, false, self.base.width) catch return;
        self.current_guide.?.move(p.y - 7);
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
            rect.top = self.base.top;
            rect.bottom = self.base.top + self.base.height;
            rect.left = self.base.left;
            rect.right = self.base.left + self.base.width;
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
