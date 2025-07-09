const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");
const AlphaWnd = @import("alpha_wnd.zig");
const globals = @import("globals.zig");

const Self = @This();

base: AlphaWnd,
buffer: @import("cached_bitmap.zig"),
vertical: bool,
distance: i32 = 0,
bounds: win.RECT,
allocator: std.mem.Allocator,
last_display_mode: u32 = 0,
last_control_state: bool = false,
last_position: i32 = 0,

// Static brushes and pens (initialized once)
var transp_brush: ?*gdip.Brush = null;
var coord_font: ?*gdip.Font = null;
var coord_brush: ?*gdip.Brush = null;
var coord_under_color = gdip.makeColor(190, 255, 255, 255);
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
        .buffer = .init(if (vertical) 50 else bounds.right - bounds.left, if (vertical) bounds.bottom - bounds.top else 50),
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
    try self.buffer.resize(width, height);
    self.base.width = width;
    self.base.height = height;
    if (self.vertical)
        self.base.top = bounds.top
    else
        self.base.left = bounds.left;
    self.last_display_mode = 100;
    try self.repaint();
}

fn initializeStatics() !void {
    transp_brush = try gdip.createSolidFill(gdip.makeColor(1, 130, 130, 130));
    const font_family = try gdip.createFontFamilyFromName(std.unicode.utf8ToUtf16LeStringLiteral("Calibri"), null);
    defer gdip.deleteFontFamily(font_family) catch {};
    coord_font = try gdip.createFont(font_family, 11, .FontStyleRegular, .UnitPixel);
    coord_brush = try gdip.createSolidFill(gdip.makeColor(255, 0, 0, 0));
    line_pen = try gdip.createPen1(gdip.makeColor(255, 74, 255, 255), 1.0, .UnitPixel);
}

pub fn deinit(self: *Self) void {
    self.buffer.deinit();
    self.base.deinit();
    self.allocator.destroy(self);
}

fn needsRepaint(self: *Self) bool {
    const current_pos = if (self.vertical) self.base.left else self.base.top;
    return self.last_display_mode != globals.display_mode or
        self.last_control_state != globals.control_pressed or
        self.last_position != current_pos;
}

fn repaint(self: *Self) !void {
    if (!self.needsRepaint()) return;
    const graphics = try self.buffer.beginDraw();
    try gdip.graphicsClear(graphics, gdip.makeColor(0, 0, 0, 0));
    const width = self.bounds.right - self.bounds.left;
    const height = self.bounds.bottom - self.bounds.top;
    if (globals.control_pressed)
        try gdip.fillRectangleI(graphics, transp_brush.?, 0, 0, if (self.vertical) 5 else width, if (self.vertical) height else 5);
    if (self.vertical)
        try gdip.drawLineI(graphics, line_pen.?, 2, 0, 2, height)
    else
        try gdip.drawLineI(graphics, line_pen.?, 0, 2, width, 2);

    self.last_display_mode = globals.display_mode;
    self.last_control_state = globals.control_pressed;
    self.last_position = if (self.vertical) self.base.left else self.base.top;
    _ = try self.drawCoordinates(graphics);
    self.base.update(try self.buffer.endDraw());
}

fn drawCoordinates(self: *Self, graphics: *gdip.Graphics) !bool {
    if (globals.display_mode == 0)
        return false;
    if (globals.display_mode == 2)
        self.distance = globals.getDistance(self);
    const rect = if (self.vertical)
        gdip.Rect{ .X = 3, .Y = 16, .Width = 35, .Height = 12 }
    else
        gdip.Rect{ .X = 16, .Y = 3, .Width = 35, .Height = 12 };
    try self.drawText(graphics, rect, if (self.vertical) self.base.left else self.base.top);
    return true;
}

fn drawText(self: *Self, graphics: *gdip.Graphics, rect: gdip.Rect, val: i32) !void {
    try gdip.setClipRectI(graphics, rect.X, rect.Y, rect.Width, rect.Height, .CombineModeReplace);
    defer gdip.resetClip(graphics) catch {};
    try gdip.graphicsClear(graphics, coord_under_color);
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const local_allocator = fba.allocator();
    const text_str = switch (globals.display_mode) {
        1 => try std.fmt.allocPrint(local_allocator, "{}", .{val + 2}),
        2 => try std.fmt.allocPrint(local_allocator, "+{}", .{val - self.distance}),
        else => return,
    };
    gdip.drawString(
        graphics,
        try std.unicode.utf8ToUtf16LeAllocZ(local_allocator, text_str),
        -1,
        coord_font.?,
        &gdip.makeRect(@floatFromInt(rect.X), @floatFromInt(rect.Y - 1), @floatFromInt(rect.Width), @floatFromInt(rect.Height)),
        null,
        coord_brush.?,
    ) catch {};
}

fn processMsg(base: *AlphaWnd, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) ?win.LRESULT {
    const self: *Self = @fieldParentPtr("base", base);
    _ = wparam;
    switch (msg) {
        win.WM_NCHITTEST => return win.HTCAPTION,
        win.WM_NCLBUTTONDOWN => {
            globals.bringToFrontAll();
            self.bringToFront();
            return null;
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
            self.repaint() catch {};
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
            self.repaint() catch {};
            if (globals.display_mode == 2)
                globals.notifyAll();
            return 0;
        },
        win.WM_SETCURSOR => {
            _ = win.SetCursor(if (self.vertical) globals.size_h_cursor else globals.size_v_cursor);
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
    self.last_display_mode = 100;
    self.repaint() catch {};
    self.bringToFront();
}

pub fn move(self: *Self, value: i32) void {
    self.base.move(if (self.vertical) value else null, if (self.vertical) null else value);
    self.repaint() catch {};
}

pub fn bringToFront(self: *Self) void {
    self.base.bringToFront(win.HWND_TOPMOST);
}
