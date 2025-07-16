const std = @import("std");
const win = @import("windows.zig");

pub const Graphics = opaque {};
pub const Bitmap = opaque {};
pub const Brush = opaque {};
pub const Pen = opaque {};
pub const Font = opaque {};
pub const FontFamily = opaque {};
pub const StringFormat = opaque {};
pub const Image = opaque {};

pub const Status = enum(c_int) {
    Ok = 0,
    GenericError = 1,
    InvalidParameter = 2,
    OutOfMemory = 3,
    ObjectBusy = 4,
    InsufficientBuffer = 5,
    NotImplemented = 6,
    Win32Error = 7,
    WrongState = 8,
    Aborted = 9,
    FileNotFound = 10,
    ValueOverflow = 11,
    AccessDenied = 12,
    UnknownImageFormat = 13,
    FontFamilyNotFound = 14,
    FontStyleNotFound = 15,
    NotTrueTypeFont = 16,
    UnsupportedGdiplusVersion = 17,
    GdiplusNotInitialized = 18,
    PropertyNotFound = 19,
    PropertyNotSupported = 20,
    ProfileNotFound = 21,
};

pub const PixelFormat32bppPARGB: c_int = 0xE200B;

const GdiplusStartupInput = extern struct {
    GdiplusVersion: win.DWORD,
    DebugEventCallback: ?*anyopaque,
    SuppressBackgroundThread: win.BOOL,
    SuppressExternalCodecs: win.BOOL,
};

pub const Rect = extern struct {
    X: c_int,
    Y: c_int,
    Width: c_int,
    Height: c_int,
};

pub const RectF = extern struct {
    X: f32,
    Y: f32,
    Width: f32,
    Height: f32,
};

pub const PointF = extern struct {
    X: f32,
    Y: f32,
};

pub const Color = win.DWORD;

pub const Unit = enum(c_int) {
    UnitWorld = 0,
    UnitDisplay = 1,
    UnitPixel = 2,
    UnitPoint = 3,
    UnitInch = 4,
    UnitDocument = 5,
    UnitMillimeter = 6,
};

pub const FontStyle = enum(c_int) {
    FontStyleRegular = 0,
    FontStyleBold = 1,
    FontStyleItalic = 2,
    FontStyleBoldItalic = 3,
    FontStyleUnderline = 4,
    FontStyleStrikeout = 8,
};

pub const TextRenderingHint = enum(c_int) {
    TextRenderingHintSystemDefault = 0,
    TextRenderingHintSingleBitPerPixelGridFit = 1,
    TextRenderingHintSingleBitPerPixel = 2,
    TextRenderingHintAntiAliasGridFit = 3,
    TextRenderingHintAntiAlias = 4,
    TextRenderingHintClearTypeGridFit = 5,
};

pub const CombineMode = enum(c_int) {
    CombineModeReplace = 0,
    CombineModeIntersect = 1,
    CombineModeUnion = 2,
    CombineModeXor = 3,
    CombineModeExclude = 4,
    CombineModeComplement = 5,
};

extern "gdiplus" fn GdiplusStartup(token: *usize, input: *const GdiplusStartupInput, output: ?*anyopaque) callconv(.C) Status;
extern "gdiplus" fn GdiplusShutdown(token: usize) callconv(.C) void;
extern "gdiplus" fn GdipCreateBitmapFromScan0(width: c_int, height: c_int, stride: c_int, format: c_int, scan0: ?*anyopaque, bitmap: *?*Bitmap) callconv(.C) Status;
extern "gdiplus" fn GdipGetImageGraphicsContext(image: *Image, graphics: *?*Graphics) callconv(.C) Status;
extern "gdiplus" fn GdipDeleteGraphics(graphics: *Graphics) callconv(.C) Status;
extern "gdiplus" fn GdipDisposeImage(image: *Image) callconv(.C) Status;
extern "gdiplus" fn GdipGetImageWidth(image: *Image, width: *win.UINT) callconv(.C) Status;
extern "gdiplus" fn GdipGetImageHeight(image: *Image, height: *win.UINT) callconv(.C) Status;
extern "gdiplus" fn GdipCreateHBITMAPFromBitmap(bitmap: *Bitmap, hbmReturn: *?win.HBITMAP, background: Color) callconv(.C) Status;
extern "gdiplus" fn GdipGraphicsClear(graphics: *Graphics, color: Color) callconv(.C) Status;
extern "gdiplus" fn GdipSetTextRenderingHint(graphics: *Graphics, mode: TextRenderingHint) callconv(.C) Status;
extern "gdiplus" fn GdipCreateSolidFill(color: Color, brush: *?*Brush) callconv(.C) Status;
extern "gdiplus" fn GdipDeleteBrush(brush: *Brush) callconv(.C) Status;
extern "gdiplus" fn GdipCreatePen1(color: Color, width: f32, unit: Unit, pen: *?*Pen) callconv(.C) Status;
extern "gdiplus" fn GdipDeletePen(pen: *Pen) callconv(.C) Status;
extern "gdiplus" fn GdipCreateFontFamilyFromName(name: [*:0]const u16, fontCollection: ?*anyopaque, fontFamily: *?*FontFamily) callconv(.C) Status;
extern "gdiplus" fn GdipCreateFont(fontFamily: *FontFamily, emSize: f32, style: FontStyle, unit: Unit, font: *?*Font) callconv(.C) Status;
extern "gdiplus" fn GdipDeleteFont(font: *Font) callconv(.C) Status;
extern "gdiplus" fn GdipDeleteFontFamily(fontFamily: *FontFamily) callconv(.C) Status;
extern "gdiplus" fn GdipFillRectangleI(graphics: *Graphics, brush: *Brush, x: c_int, y: c_int, width: c_int, height: c_int) callconv(.C) Status;
extern "gdiplus" fn GdipDrawLineI(graphics: *Graphics, pen: *Pen, x1: c_int, y1: c_int, x2: c_int, y2: c_int) callconv(.C) Status;
extern "gdiplus" fn GdipDrawString(graphics: *Graphics, string: [*:0]const u16, length: c_int, font: *Font, layoutRect: *const RectF, stringFormat: ?*StringFormat, brush: *Brush) callconv(.C) Status;
extern "gdiplus" fn GdipMeasureString(graphics: *Graphics, string: [*:0]const u16, length: c_int, font: *Font, layoutRect: *const RectF, stringFormat: ?*StringFormat, boundingBox: *RectF, codepointsFitted: ?*c_int, linesFilled: ?*c_int) callconv(.C) Status;
extern "gdiplus" fn GdipSetClipRectI(graphics: *Graphics, x: c_int, y: c_int, width: c_int, height: c_int, combineMode: CombineMode) callconv(.C) Status;
extern "gdiplus" fn GdipResetClip(graphics: *Graphics) callconv(.C) Status;

pub const GdiplusError = error{
    GenericError,
    InvalidParameter,
    OutOfMemory,
    UnknownImageFormat,
    FontFamilyNotFound,
    FontStyleNotFound,
    NotTrueTypeFont,
};

fn statusToError(status: Status) GdiplusError {
    return switch (status) {
        .GenericError => GdiplusError.GenericError,
        .InvalidParameter => GdiplusError.InvalidParameter,
        .OutOfMemory => GdiplusError.OutOfMemory,
        .UnknownImageFormat => GdiplusError.UnknownImageFormat,
        .FontFamilyNotFound => GdiplusError.FontFamilyNotFound,
        .FontStyleNotFound => GdiplusError.FontStyleNotFound,
        .NotTrueTypeFont => GdiplusError.NotTrueTypeFont,
        else => GdiplusError.GenericError,
    };
}

pub fn makeColor(a: u8, r: u8, g: u8, b: u8) Color {
    return (@as(Color, a) << 24) | (@as(Color, r) << 16) | (@as(Color, g) << 8) | @as(Color, b);
}

pub fn makeRect(x: f32, y: f32, width: f32, height: f32) RectF {
    return RectF{ .X = x, .Y = y, .Width = width, .Height = height };
}

var gdiplus_token: usize = 0;

pub fn startup() !void {
    const input = GdiplusStartupInput{ .GdiplusVersion = 1, .DebugEventCallback = null, .SuppressBackgroundThread = 0, .SuppressExternalCodecs = 0 };
    const status = GdiplusStartup(&gdiplus_token, &input, null);
    if (status != .Ok)
        return statusToError(status);
}

pub fn shutdown() void {
    if (gdiplus_token != 0) {
        GdiplusShutdown(gdiplus_token);
        gdiplus_token = 0;
    }
}

pub fn createBitmapFromScan0(width: c_int, height: c_int, stride: c_int, format: c_int, scan0: ?*anyopaque) !*Bitmap {
    var bitmap: ?*Bitmap = null;
    const status = GdipCreateBitmapFromScan0(width, height, stride, format, scan0, &bitmap);
    if (status != .Ok)
        return statusToError(status);
    return bitmap.?;
}

pub fn createGraphicsFromImage(image: *Image) !*Graphics {
    var graphics: ?*Graphics = null;
    const status = GdipGetImageGraphicsContext(image, &graphics);
    if (status != .Ok)
        return statusToError(status);
    return graphics.?;
}

pub fn deleteGraphics(graphics: *Graphics) !void {
    const status = GdipDeleteGraphics(graphics);
    if (status != .Ok)
        return statusToError(status);
}

pub fn disposeImage(image: *Image) !void {
    const status = GdipDisposeImage(image);
    if (status != .Ok)
        return statusToError(status);
}

pub fn getImageWidth(image: *Image) !win.UINT {
    var width: win.UINT = 0;
    const status = GdipGetImageWidth(image, &width);
    if (status != .Ok)
        return statusToError(status);
    return width;
}

pub fn getImageHeight(image: *Image) !win.UINT {
    var height: win.UINT = 0;
    const status = GdipGetImageHeight(image, &height);
    if (status != .Ok)
        return statusToError(status);
    return height;
}

pub fn createHBITMAPFromBitmap(bitmap: *Bitmap, background: Color) !win.HBITMAP {
    var hbitmap: ?win.HBITMAP = null;
    const status = GdipCreateHBITMAPFromBitmap(bitmap, &hbitmap, background);
    if (status != .Ok)
        return statusToError(status);
    return hbitmap.?;
}

pub fn graphicsClear(graphics: *Graphics, color: Color) !void {
    const status = GdipGraphicsClear(graphics, color);
    if (status != .Ok)
        return statusToError(status);
}

pub fn setTextRenderingHint(graphics: *Graphics, mode: TextRenderingHint) !void {
    const status = GdipSetTextRenderingHint(graphics, mode);
    if (status != .Ok)
        return statusToError(status);
}

pub fn createSolidFill(color: Color) !*Brush {
    var brush: ?*Brush = null;
    const status = GdipCreateSolidFill(color, &brush);
    if (status != .Ok)
        return statusToError(status);
    return brush.?;
}

pub fn deleteBrush(brush: *Brush) !void {
    const status = GdipDeleteBrush(brush);
    if (status != .Ok)
        return statusToError(status);
}

pub fn createPen1(color: Color, width: f32, unit: Unit) !*Pen {
    var pen: ?*Pen = null;
    const status = GdipCreatePen1(color, width, unit, &pen);
    if (status != .Ok)
        return statusToError(status);
    return pen.?;
}

pub fn deletePen(pen: *Pen) !void {
    const status = GdipDeletePen(pen);
    if (status != .Ok)
        return statusToError(status);
}

pub fn createFontFamilyFromName(name: [*:0]const u16, fontCollection: ?*anyopaque) !*FontFamily {
    var fontFamily: ?*FontFamily = null;
    const status = GdipCreateFontFamilyFromName(name, fontCollection, &fontFamily);
    if (status != .Ok)
        return statusToError(status);
    return fontFamily.?;
}

pub fn createFont(fontFamily: *FontFamily, emSize: f32, style: FontStyle, unit: Unit) !*Font {
    var font: ?*Font = null;
    const status = GdipCreateFont(fontFamily, emSize, style, unit, &font);
    if (status != .Ok)
        return statusToError(status);
    return font.?;
}

pub fn deleteFont(font: *Font) !void {
    const status = GdipDeleteFont(font);
    if (status != .Ok)
        return statusToError(status);
}

pub fn deleteFontFamily(fontFamily: *FontFamily) !void {
    const status = GdipDeleteFontFamily(fontFamily);
    if (status != .Ok)
        return statusToError(status);
}

pub fn fillRectangleI(graphics: *Graphics, brush: *Brush, x: c_int, y: c_int, width: c_int, height: c_int) !void {
    const status = GdipFillRectangleI(graphics, brush, x, y, width, height);
    if (status != .Ok)
        return statusToError(status);
}

pub fn drawLineI(graphics: *Graphics, pen: *Pen, x1: c_int, y1: c_int, x2: c_int, y2: c_int) !void {
    const status = GdipDrawLineI(graphics, pen, x1, y1, x2, y2);
    if (status != .Ok)
        return statusToError(status);
}

pub fn drawString(graphics: *Graphics, string: [*:0]const u16, length: c_int, font: *Font, layoutRect: *const RectF, stringFormat: ?*StringFormat, brush: *Brush) !void {
    const status = GdipDrawString(graphics, string, length, font, layoutRect, stringFormat, brush);
    if (status != .Ok)
        return statusToError(status);
}

pub fn measureString(graphics: *Graphics, string: [*:0]const u16, length: c_int, font: *Font, layoutRect: *const RectF, stringFormat: ?*StringFormat) !RectF {
    var boundingBox: RectF = undefined;
    const status = GdipMeasureString(graphics, string, length, font, layoutRect, stringFormat, &boundingBox, null, null);
    if (status != .Ok)
        return statusToError(status);
    return boundingBox;
}

pub fn setClipRectI(graphics: *Graphics, x: c_int, y: c_int, width: c_int, height: c_int, combineMode: CombineMode) !void {
    const status = GdipSetClipRectI(graphics, x, y, width, height, combineMode);
    if (status != .Ok)
        return statusToError(status);
}

pub fn resetClip(graphics: *Graphics) !void {
    const status = GdipResetClip(graphics);
    if (status != .Ok)
        return statusToError(status);
}

pub const CachedBitmap = struct {
    width: i32,
    height: i32,
    hbitmap: win.HBITMAP,
    hdc: win.HDC,
    bits: *anyopaque,
    gd_bitmap: *Bitmap,
    gd_graphics: *Graphics,

    const Self = @This();

    pub fn init(width: i32, height: i32) !Self {
        const hdc = win.GetDC(null) orelse return error.GetDCFailed;
        defer _ = win.ReleaseDC(null, hdc);
        var bits: ?*anyopaque = null;
        const hbitmap = win.CreateDIBSection(hdc, &std.mem.zeroInit(win.BITMAPV5HEADER, .{
            .bV5Size = @sizeOf(win.BITMAPV5HEADER),
            .bV5Width = width,
            .bV5Height = -height, // Negative for top-down DIB
            .bV5Planes = 1,
            .bV5BitCount = 32,
            .bV5Compression = win.BI_RGB,
            .bV5RedMask = 0x00FF0000,
            .bV5GreenMask = 0x0000FF00,
            .bV5BlueMask = 0x000000FF,
            .bV5AlphaMask = 0xFF000000,
            .bV5CSType = win.LCS_WINDOWS_COLOR_SPACE,
        }), win.DIB_RGB_COLORS, &bits, null, 0) orelse return error.CreateDIBSectionFailed;
        const gd_bitmap = try createBitmapFromScan0(width, height, width * 4, PixelFormat32bppPARGB, bits);
        const self = Self{
            .width = width,
            .height = height,
            .hbitmap = hbitmap,
            .bits = bits.?,
            .hdc = win.CreateCompatibleDC(hdc) orelse return error.CreateCompatibleDCFailed,
            .gd_bitmap = gd_bitmap,
            .gd_graphics = try createGraphicsFromImage(@ptrCast(gd_bitmap)),
        };
        _ = win.SelectObject(self.hdc, hbitmap);
        try setTextRenderingHint(self.gd_graphics, .TextRenderingHintAntiAliasGridFit);
        return self;
    }

    pub fn deinit(self: *Self) void {
        deleteGraphics(self.gd_graphics) catch {};
        disposeImage(@ptrCast(self.gd_bitmap)) catch {};
        _ = win.DeleteDC(self.hdc);
        _ = win.DeleteObject(self.hbitmap);
    }
};
