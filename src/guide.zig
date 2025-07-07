const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");
const AlphaWnd = @import("alpha_wnd.zig");
const globals = @import("globals.zig");

const Self = @This();

base: AlphaWnd,
graphics: ?*gdip.Graphics = null,
vertical: bool,
distance: i32 = 0,
bounds: win.RECT,
allocator: std.mem.Allocator,

// Static brushes and pens (initialized once)
var transp_brush: ?*gdip.Brush = null;
var coord_font: ?*gdip.Font = null;
var coord_brush: ?*gdip.Brush = null;
var coord_under_color: gdip.Color = 0;
var line_pen: ?*gdip.Pen = null;
var initialized: bool = false;

pub fn create(allocator: std.mem.Allocator, vertical: bool, bounds: win.RECT) !*Self {
    if (!initialized) {
        try initializeStatics();
        initialized = true;
    }
    const self = try allocator.create(Self);
    self.* = Self{
        .base = undefined,
        .vertical = vertical,
        .allocator = allocator,
        .bounds = bounds,
    };

    try AlphaWnd.createAt(
        &self.base,
        win.CS_DBLCLKS,
        win.WS_POPUP,
        win.WS_EX_TOOLWINDOW | win.WS_EX_TOPMOST,
        null,
        "Guide",
        "GuideWndClass",
        null,
        null,
    );
    self.base.processMsg = processMsg;
    try self.setBounds(bounds);
    try globals.addGuide(self);
    self.notify();
    return self;
}

pub fn setBounds(self: *Self, bounds: win.RECT) !void {
    self.bounds = bounds;
    const width = if (self.vertical) 50 else bounds.right - bounds.left;
    const height = if (self.vertical) bounds.bottom - bounds.top else 50;
    if (self.vertical)
        self.base.top = bounds.top
    else
        self.base.left = bounds.left;
    if (self.graphics) |g|
        gdip.deleteGraphics(g) catch {};
    if (self.base.bitmap) |bmp|
        gdip.disposeImage(@ptrCast(bmp)) catch {};
    // Create bitmap and graphics
    self.base.bitmap = try gdip.createBitmapFromScan0(width, height, 0, gdip.PixelFormat32bppARGB, null);
    self.graphics = try gdip.createGraphicsFromImage(@ptrCast(self.base.bitmap.?));
    try gdip.setTextRenderingHint(self.graphics.?, .TextRenderingHintAntiAliasGridFit);
    self.repaint();
    self.base.redraw();
}

fn initializeStatics() !void {
    transp_brush = try gdip.createSolidFill(gdip.makeColor(1, 130, 130, 130));
    const calibri_str = std.unicode.utf8ToUtf16LeStringLiteral("Calibri");
    const font_family = try gdip.createFontFamilyFromName(calibri_str, null);
    defer gdip.deleteFontFamily(font_family) catch {};
    coord_font = try gdip.createFont(font_family, 11, .FontStyleRegular, .UnitPixel);
    coord_brush = try gdip.createSolidFill(gdip.makeColor(255, 0, 0, 0));
    coord_under_color = gdip.makeColor(190, 255, 255, 255);
    line_pen = try gdip.createPen1(gdip.makeColor(255, 74, 255, 255), 1.0, .UnitPixel);
}

pub fn deinit(self: *Self) void {
    if (self.graphics) |g|
        gdip.deleteGraphics(g) catch {};
    self.base.deinit();
    self.allocator.destroy(self);
}

fn repaint(self: *Self) void {
    if (self.graphics == null) return;
    gdip.graphicsClear(self.graphics.?, gdip.makeColor(0, 0, 0, 0)) catch return;
    const width = self.bounds.right - self.bounds.left;
    const height = self.bounds.bottom - self.bounds.top;
    if (globals.control_pressed)
        gdip.fillRectangleI(self.graphics.?, transp_brush.?, 0, 0, if (self.vertical) 5 else width, if (self.vertical) height else 5) catch {};
    if (self.vertical)
        gdip.drawLineI(self.graphics.?, line_pen.?, 2, 0, 2, height) catch {}
    else
        gdip.drawLineI(self.graphics.?, line_pen.?, 0, 2, width, 2) catch {};
    if (!self.onMove())
        self.base.invalidate();
}

fn onMove(self: *Self) bool {
    if (self.graphics == null or globals.display_mode == 0)
        return false;
    if (globals.display_mode == 2)
        self.distance = globals.getDistance(self);
    const rect = if (self.vertical)
        gdip.Rect{ .X = 3, .Y = 16, .Width = 35, .Height = 12 }
    else
        gdip.Rect{ .X = 16, .Y = 3, .Width = 35, .Height = 12 };
    self.doDraw(rect, if (self.vertical) self.base.left else self.base.top);
    self.base.invalidate();
    return true;
}

fn doDraw(self: *Self, rect: gdip.Rect, val: i32) void {
    gdip.setClipRectI(self.graphics.?, rect.X, rect.Y, rect.Width, rect.Height, .CombineModeReplace) catch return;
    gdip.graphicsClear(self.graphics.?, coord_under_color) catch return;
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const local_allocator = fba.allocator();
    const text_str = switch (globals.display_mode) {
        1 => std.fmt.allocPrint(local_allocator, "{}", .{val + 2}) catch return,
        2 => std.fmt.allocPrint(local_allocator, "+{}", .{val - self.distance}) catch return,
        else => return,
    };
    gdip.drawString(
        self.graphics.?,
        std.unicode.utf8ToUtf16LeAllocZ(local_allocator, text_str) catch return,
        -1,
        coord_font.?,
        &gdip.makeRect(@floatFromInt(rect.X), @floatFromInt(rect.Y - 1), @floatFromInt(rect.Width), @floatFromInt(rect.Height)),
        null,
        coord_brush.?,
    ) catch {};
    gdip.resetClip(self.graphics.?) catch {};
}

fn processMsg(base: *AlphaWnd, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) ?win.LRESULT {
    const self: *Self = @fieldParentPtr("base", base);
    _ = wparam;
    switch (msg) {
        win.WM_NCHITTEST => return win.HTCAPTION,
        win.WM_ENTERSIZEMOVE => {
            globals.bringToFrontAll();
            _ = win.SetWindowPos(self.base.hwnd.?, win.HWND_TOPMOST, 0, 0, 0, 0, win.SWP_NOMOVE | win.SWP_NOSIZE | win.SWP_NOACTIVATE);
            return 0;
        },
        win.WM_MOVING => {
            const rect: *win.RECT = @ptrFromInt(@as(usize, @bitCast(lparam)));
            if (self.vertical) {
                rect.top = self.base.top;
                rect.bottom = self.base.top + self.base.height;
            } else {
                rect.left = self.base.left;
                rect.right = self.base.left + self.base.width;
            }
            _ = self.onMove();
            return 0;
        },
        win.WM_EXITSIZEMOVE => {
            const should_remove = if (self.vertical)
                self.base.left < self.bounds.left + 5
            else
                self.base.top < self.bounds.top + 5;
            if (should_remove) {
                globals.removeGuide(self);
                return 0;
            }
            _ = self.onMove();
            if (globals.display_mode == 2)
                globals.notifyAll();
            return 0;
        },
        win.WM_SETCURSOR => {
            const cursor = if (self.vertical) globals.size_h_cursor else globals.size_v_cursor;
            _ = win.SetCursor(cursor);
            return 0;
        },
        else => return null,
    }
}

pub fn notify(self: *Self) void {
    const current_ex_style = win.GetWindowLongPtrA(self.base.hwnd.?, win.GWLP_EXSTYLE);
    const new_style = if (globals.control_pressed)
        current_ex_style & ~@as(win.LONG_PTR, win.WS_EX_TRANSPARENT)
    else
        current_ex_style | win.WS_EX_TRANSPARENT;
    _ = win.SetWindowLongPtrA(self.base.hwnd.?, win.GWLP_EXSTYLE, new_style);
    if (globals.display_mode == 0)
        gdip.graphicsClear(self.graphics.?, gdip.makeColor(0, 0, 0, 0)) catch {};
    self.repaint();
    _ = win.SetWindowPos(self.base.hwnd.?, win.HWND_TOPMOST, 0, 0, 0, 0, win.SWP_NOMOVE | win.SWP_NOSIZE | win.SWP_NOACTIVATE);
}

pub fn move(self: *Self, value: i32) void {
    self.base.move(if (self.vertical) value else null, if (self.vertical) null else value);
    _ = self.onMove();
}

pub fn bringToFront(self: *Self) void {
    self.base.bringToFront(-1);
}
