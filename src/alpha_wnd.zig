const std = @import("std");
const win = @import("windows.zig");
const gdip = @import("gdiplus.zig");

const Self = @This();

hwnd: ?win.HWND = null,
hdc: ?win.HDC = null,
blend_func: win.BLENDFUNCTION = .{ .BlendOp = win.AC_SRC_OVER, .BlendFlags = 0, .SourceConstantAlpha = 255, .AlphaFormat = win.AC_SRC_ALPHA },
left: i32 = 0,
top: i32 = 0,
width: i32 = 100,
height: i32 = 100,
bitmap: ?*gdip.Bitmap = null,
parent: ?win.HWND = null,

// Function pointer for message processing
processMsg: ?*const fn (*Self, win.UINT, win.WPARAM, win.LPARAM) ?win.LRESULT = null,

pub fn createAt(
    self: *Self,
    cls_style: win.UINT,
    dw_style: win.DWORD,
    dw_ex_style: win.DWORD,
    h_menu: ?win.HMENU,
    caption: [*:0]const u8,
    cls_name: [*:0]const u8,
    parent: ?win.HWND,
    icon: ?win.HICON,
) !void {
    self.* = .{ .parent = parent };
    const hinstance = win.GetModuleHandleW(null) orelse return error.OperationFailed;
    _ = win.RegisterClassA(&.{
        .style = cls_style,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinstance,
        .hIcon = icon,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = cls_name,
    });
    self.hwnd = win.CreateWindowExA(
        dw_ex_style | win.WS_EX_LAYERED,
        cls_name,
        caption,
        dw_style,
        self.left,
        self.top,
        self.width,
        self.height,
        parent,
        h_menu,
        hinstance,
        self,
    ) orelse return error.CreateWindowFailed;
}

pub fn deinit(self: *Self) void {
    if (self.bitmap) |bmp|
        gdip.disposeImage(@ptrCast(bmp)) catch {};
    if (self.hdc) |hdc|
        _ = win.ReleaseDC(self.hwnd, hdc);
    _ = win.DestroyWindow(self.hwnd.?);
}

fn wndProc(hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) callconv(.C) win.LRESULT {
    const self_ptr = win.GetWindowLongPtrA(hwnd, win.GWLP_USERDATA);
    switch (msg) {
        win.WM_CREATE => {
            const create_struct: *win.CREATESTRUCT = @ptrFromInt(@as(usize, @bitCast(lparam)));
            const self: *Self = @ptrCast(@alignCast(create_struct.lpCreateParams));
            _ = win.SetWindowLongPtrA(hwnd, win.GWLP_USERDATA, @bitCast(@intFromPtr(self)));
            self.hwnd = hwnd;
            self.hdc = win.GetDC(hwnd) orelse null;
            self.bitmap = gdip.createBitmapFromScan0(@intCast(self.width), @intCast(self.height), 0, gdip.PixelFormat32bppARGB, null) catch null;
            return win.DefWindowProcA(hwnd, msg, wparam, lparam);
        },
        else => {
            if (self_ptr != 0) {
                const self: *Self = @ptrFromInt(@as(usize, @intCast(self_ptr)));
                if (msg == win.WM_MOVE) {
                    self.left = @as(i16, @truncate(lparam & 0xFFFF));
                    self.top = @as(i16, @truncate((lparam >> 16) & 0xFFFF));
                }
                if (self.processMsg) |processMsgFn|
                    if (processMsgFn(self, msg, wparam, lparam)) |result|
                        return result;
            }
            return win.DefWindowProcA(hwnd, msg, wparam, lparam);
        },
    }
}

pub fn show(self: *Self) void {
    _ = win.ShowWindow(self.hwnd.?, 1);
}

pub fn invalidate(self: *Self) void {
    if (self.bitmap == null or self.hwnd == null or self.hdc == null) return;
    const hbitmap = gdip.createHBITMAPFromBitmap(self.bitmap.?, 0) catch return;
    defer _ = win.DeleteObject(hbitmap);
    const bmp_dc = win.CreateCompatibleDC(self.hdc) orelse return;
    defer _ = win.DeleteDC(bmp_dc);
    const old_bmp = win.SelectObject(bmp_dc, hbitmap);
    defer _ = win.SelectObject(bmp_dc, old_bmp);
    _ = win.UpdateLayeredWindow(
        self.hwnd.?,
        self.hdc,
        &.{ .x = self.left, .y = self.top },
        &.{ .cx = self.width, .cy = self.height },
        bmp_dc,
        &.{ .x = 0, .y = 0 },
        0,
        &self.blend_func,
        win.ULW_ALPHA,
    );
}

pub fn redraw(self: *Self) void {
    if (self.bitmap) |bmp| {
        self.width = @intCast(gdip.getImageWidth(@ptrCast(bmp)) catch return);
        self.height = @intCast(gdip.getImageHeight(@ptrCast(bmp)) catch return);
        self.invalidate();
    }
}

pub fn move(self: *Self, left: ?i32, top: ?i32) void {
    self.top = top orelse self.top;
    self.left = left orelse self.left;
    _ = win.SetWindowPos(self.hwnd.?, null, self.left, self.top, self.width, self.height, win.SWP_NOZORDER | win.SWP_NOSIZE | win.SWP_NOACTIVATE);
}

pub fn bringToFront(self: *Self, afterHwnd: isize) void {
    _ = win.SetWindowPos(self.hwnd.?, @ptrFromInt(@as(usize, @bitCast(@as(isize, afterHwnd)))), 0, 0, 0, 0, win.SWP_NOMOVE | win.SWP_NOSIZE | win.SWP_NOACTIVATE);
}

pub fn setAlphaValue(self: *Self, value: u8) void {
    self.blend_func.SourceConstantAlpha = value;
    self.invalidate();
}

pub fn setBitmap(self: *Self, bitmap: *gdip.Bitmap) void {
    if (self.bitmap) |old_bmp|
        gdip.disposeImage(@ptrCast(old_bmp)) catch {};
    self.bitmap = bitmap;
}
