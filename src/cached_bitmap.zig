const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");

width: i32,
height: i32,
hbitmap: ?win.HBITMAP = null,
bmp_dc: ?win.HDC = null,
bits: ?*anyopaque = null,
gd_bitmap: ?*gdip.Bitmap = null,
gd_graphics: ?*gdip.Graphics = null,

const Self = @This();

pub fn init(width: i32, height: i32) Self {
    return Self{ .width = width, .height = height };
}

pub fn deinit(self: *Self) void {
    self.cleanup();
}

fn cleanup(self: *Self) void {
    if (self.gd_graphics) |graphics| {
        gdip.deleteGraphics(graphics) catch {};
        self.gd_graphics = null;
    }
    if (self.gd_bitmap) |bitmap| {
        gdip.disposeImage(@ptrCast(bitmap)) catch {};
        self.gd_bitmap = null;
    }
    if (self.bmp_dc) |dc| {
        _ = win.DeleteDC(dc);
        self.bmp_dc = null;
    }
    if (self.hbitmap) |h| {
        _ = win.DeleteObject(h);
        self.hbitmap = null;
        self.bits = null;
    }
}

pub fn resize(self: *Self, width: i32, height: i32) !void {
    if (self.width == width and self.height == height) return;
    self.cleanup();
    self.width = width;
    self.height = height;
}

pub fn beginDraw(self: *Self) !*gdip.Graphics {
    if (self.gd_graphics) |g| return g;
    self.cleanup();
    const hdc = win.GetDC(null) orelse return error.GetDCFailed;
    defer _ = win.ReleaseDC(null, hdc);
    self.hbitmap = win.CreateDIBSection(hdc, @ptrCast(&std.mem.zeroInit(win.BITMAPV5HEADER, .{
        .bV5Size = @sizeOf(win.BITMAPV5HEADER),
        .bV5Width = self.width,
        .bV5Height = -self.height, // Negative for top-down DIB
        .bV5Planes = 1,
        .bV5BitCount = 32,
        .bV5Compression = win.BI_RGB,
        .bV5RedMask = 0x00FF0000,
        .bV5GreenMask = 0x0000FF00,
        .bV5BlueMask = 0x000000FF,
        .bV5AlphaMask = 0xFF000000,
        .bV5CSType = win.LCS_WINDOWS_COLOR_SPACE,
    })), win.DIB_RGB_COLORS, &self.bits, null, 0) orelse return error.CreateDIBSectionFailed;
    self.bmp_dc = win.CreateCompatibleDC(hdc) orelse return error.CreateCompatibleDCFailed;
    _ = win.SelectObject(self.bmp_dc.?, self.hbitmap.?);
    self.gd_bitmap = try gdip.createBitmapFromScan0(self.width, self.height, self.width * 4, gdip.PixelFormat32bppPARGB, self.bits);
    self.gd_graphics = try gdip.createGraphicsFromImage(@ptrCast(self.gd_bitmap.?));
    try gdip.setTextRenderingHint(self.gd_graphics.?, .TextRenderingHintAntiAliasGridFit);
    return self.gd_graphics.?;
}

pub fn endDraw(self: *Self) !win.HDC {
    return self.bmp_dc.?;
}
