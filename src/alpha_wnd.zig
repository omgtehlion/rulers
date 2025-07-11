const std = @import("std");
const win = @import("windows.zig");

pub fn AlphaWnd(comptime processMsg: fn (*anyopaque, win.UINT, win.WPARAM, win.LPARAM) ?win.LRESULT) type {
    return struct {
        const Self = @This();

        hwnd: ?win.HWND = null,
        hdc: ?win.HDC = null,
        blend_func: win.BLENDFUNCTION = .{ .BlendOp = win.AC_SRC_OVER, .BlendFlags = 0, .SourceConstantAlpha = 255, .AlphaFormat = win.AC_SRC_ALPHA },
        left: i32 = 0,
        top: i32 = 0,
        width: i32 = 100,
        height: i32 = 100,
        parent: ?win.HWND = null,

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
                    return win.DefWindowProcA(hwnd, msg, wparam, lparam);
                },
                else => {
                    if (self_ptr != 0) {
                        const self: *Self = @ptrFromInt(@as(usize, @intCast(self_ptr)));
                        if (msg == win.WM_MOVE) {
                            self.left = @as(i16, @truncate(lparam & 0xFFFF));
                            self.top = @as(i16, @truncate((lparam >> 16) & 0xFFFF));
                        }
                        if (processMsg(self, msg, wparam, lparam)) |result|
                            return result;
                    }
                    return win.DefWindowProcA(hwnd, msg, wparam, lparam);
                },
            }
        }

        pub fn show(self: *Self) void {
            _ = win.ShowWindow(self.hwnd.?, 1);
        }

        pub fn update(self: *Self, bmp_dc: win.HDC) void {
            if (self.hwnd) |hwnd|
                _ = win.UpdateLayeredWindow(
                    hwnd,
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

        pub fn move(self: *Self, left: ?i32, top: ?i32) void {
            self.top = top orelse self.top;
            self.left = left orelse self.left;
            _ = win.SetWindowPos(self.hwnd.?, null, self.left, self.top, self.width, self.height, win.SWP_NOZORDER | win.SWP_NOSIZE | win.SWP_NOACTIVATE);
        }

        pub fn bringToFront(self: *Self, afterHwnd: win.HWND) void {
            _ = win.SetWindowPos(self.hwnd.?, afterHwnd, 0, 0, 0, 0, win.SWP_NOMOVE | win.SWP_NOSIZE | win.SWP_NOACTIVATE);
        }

        pub fn setAlphaValue(self: *Self, value: u8) void {
            self.blend_func.SourceConstantAlpha = value;
        }
    };
}
