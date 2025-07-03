const std = @import("std");
const w = std.os.windows;

pub const HWND = w.HWND;
pub const HDC = w.HDC;
pub const HMENU = w.HMENU;
pub const HICON = w.HICON;
pub const HCURSOR = w.HCURSOR;
pub const HBITMAP = *opaque {};
pub const HBRUSH = w.HBRUSH;
pub const HHOOK = *opaque {};
pub const UINT = w.UINT;
pub const WPARAM = w.WPARAM;
pub const LPARAM = w.LPARAM;
pub const LRESULT = w.LRESULT;
pub const DWORD = w.DWORD;
pub const WORD = w.WORD;
pub const BYTE = w.BYTE;
pub const BOOL = w.BOOL;
pub const LONG_PTR = w.LONG_PTR;
pub const ULONG_PTR = w.ULONG_PTR;
pub const POINT = w.POINT;
pub const SIZE = extern struct { cx: c_long, cy: c_long };
pub const RECT = w.RECT;
pub const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};
pub const WNDCLASSA = extern struct {
    style: UINT,
    lpfnWndProc: *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.C) LRESULT,
    cbClsExtra: c_int,
    cbWndExtra: c_int,
    hInstance: w.HMODULE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: [*:0]const u8,
};
pub const CREATESTRUCT = extern struct {
    lpCreateParams: ?*anyopaque,
    hInstance: w.HMODULE,
    hMenu: ?HMENU,
    hwndParent: ?HWND,
    cy: c_int,
    cx: c_int,
    y: c_int,
    x: c_int,
    style: c_long,
    lpszName: ?[*:0]const u8,
    lpszClass: ?[*:0]const u8,
    dwExStyle: DWORD,
};
pub const BLENDFUNCTION = extern struct {
    BlendOp: BYTE,
    BlendFlags: BYTE,
    SourceConstantAlpha: BYTE,
    AlphaFormat: BYTE,
};
pub const KBDLLHOOKSTRUCT = extern struct {
    vkCode: DWORD,
    scanCode: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: ULONG_PTR,
};
pub const NOTIFYICONDATAA = extern struct {
    cbSize: DWORD,
    hWnd: HWND,
    uID: UINT,
    uFlags: UINT,
    uCallbackMessage: UINT,
    hIcon: HICON,
    szTip: [128]u8,
    dwState: DWORD,
    dwStateMask: DWORD,
    szInfo: [256]u8,
    uVersion: UINT,
    szInfoTitle: [64]u8,
    dwInfoFlags: DWORD,
};

pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_MOVE = 0x0003;
pub const WM_SIZE = 0x0005;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_RBUTTONDOWN = 0x0204;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_MBUTTONUP = 0x0208;
pub const WM_NCHITTEST = 0x0084;
pub const WM_NCLBUTTONDOWN = 0x00A1;
pub const WM_NCRBUTTONDOWN = 0x00A4;
pub const WM_NCMBUTTONUP = 0x00A8;
pub const WM_SETCURSOR = 0x0020;
pub const WM_ENTERSIZEMOVE = 0x0231;
pub const WM_EXITSIZEMOVE = 0x0232;
pub const WM_MOVING = 0x0216;
pub const WM_USER = 0x0400;

pub const WS_POPUP = 0x80000000;
pub const WS_EX_LAYERED = 0x00080000;
pub const WS_EX_TOOLWINDOW = 0x00000080;
pub const WS_EX_TOPMOST = 0x00000008;
pub const WS_EX_TRANSPARENT = 0x00000020;

pub const CS_DBLCLKS = 0x0008;

pub const HTCAPTION = 2;

pub const SWP_NOMOVE = 0x0002;
pub const SWP_NOSIZE = 0x0001;
pub const SWP_NOZORDER = 0x0004;
pub const SWP_NOACTIVATE = 0x0010;

pub const HWND_TOPMOST = @as(HWND, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

pub const ULW_ALPHA = 0x00000002;

pub const AC_SRC_OVER = 0x00;
pub const AC_SRC_ALPHA = 0x01;

pub const GWLP_USERDATA = -21;
pub const GWLP_EXSTYLE = -20;

pub const PM_REMOVE = 0x0001;

pub const WH_KEYBOARD_LL = 13;

pub const VK_LCONTROL = 0xA2;

pub const NIM_ADD = 0x00000000;
pub const NIM_DELETE = 0x00000002;
pub const NIF_MESSAGE = 0x00000001;
pub const NIF_ICON = 0x00000002;
pub const NIF_TIP = 0x00000004;

pub const IDC_ARROW = @as([*:0]const u8, @ptrFromInt(32512));
pub const IDC_SIZEWE = @as([*:0]const u8, @ptrFromInt(32644));
pub const IDC_SIZENS = @as([*:0]const u8, @ptrFromInt(32645));

pub extern "user32" fn RegisterClassA(lpWndClass: *const WNDCLASSA) callconv(.C) c_ushort;
pub extern "user32" fn CreateWindowExA(dwExStyle: DWORD, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: DWORD, X: c_int, Y: c_int, nWidth: c_int, nHeight: c_int, hWndParent: ?HWND, hMenu: ?HMENU, hInstance: w.HMODULE, lpParam: ?*anyopaque) callconv(.C) ?HWND;
pub extern "user32" fn DestroyWindow(hWnd: HWND) BOOL;
pub extern "user32" fn DefWindowProcA(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.C) LRESULT;
pub extern "user32" fn GetMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(.C) BOOL;
pub extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.C) BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.C) BOOL;
pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(.C) LRESULT;
pub extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.C) void;
pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.C) BOOL;
pub extern "user32" fn UpdateLayeredWindow(hWnd: HWND, hdcDst: ?HDC, pptDst: ?*POINT, psize: ?*SIZE, hdcSrc: HDC, pptSrc: ?*POINT, crKey: DWORD, pblend: ?*BLENDFUNCTION, dwFlags: DWORD) callconv(.C) BOOL;
pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(.C) ?HDC;
pub extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.C) c_int;
pub extern "user32" fn GetDesktopWindow() callconv(.C) HWND;
pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.C) BOOL;
pub extern "user32" fn SetWindowPos(hWnd: HWND, hWndInsertAfter: ?HWND, X: c_int, Y: c_int, cx: c_int, cy: c_int, uFlags: UINT) callconv(.C) BOOL;
pub extern "user32" fn SetWindowLongPtrA(hWnd: HWND, nIndex: c_int, dwNewLong: LONG_PTR) callconv(.C) LONG_PTR;
pub extern "user32" fn GetWindowLongPtrA(hWnd: HWND, nIndex: c_int) callconv(.C) LONG_PTR;
pub extern "user32" fn SetWindowLongA(hWnd: HWND, nIndex: c_int, dwNewLong: c_long) callconv(.C) c_long;
pub extern "user32" fn GetWindowLongA(hWnd: HWND, nIndex: c_int) callconv(.C) c_long;
pub extern "user32" fn LoadCursorA(hInstance: ?w.HMODULE, lpCursorName: [*:0]const u8) callconv(.C) ?HCURSOR;
pub extern "user32" fn SetCursor(hCursor: ?HCURSOR) callconv(.C) ?HCURSOR;
pub extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.C) BOOL;
pub extern "user32" fn SetForegroundWindow(hWnd: HWND) callconv(.C) BOOL;
pub extern "user32" fn PostMessageA(hWnd: ?HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.C) BOOL;
pub extern "user32" fn WaitMessage() callconv(.C) BOOL;
pub extern "user32" fn SetWindowsHookExA(idHook: c_int, lpfn: *const fn (c_int, WPARAM, LPARAM) callconv(.C) LRESULT, hMod: w.HMODULE, dwThreadId: DWORD) callconv(.C) ?HHOOK;
pub extern "user32" fn UnhookWindowsHookEx(hhk: HHOOK) callconv(.C) BOOL;
pub extern "user32" fn CallNextHookEx(hhk: ?HHOOK, nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(.C) LRESULT;
pub extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.C) ?HDC;
pub extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.C) BOOL;
pub extern "gdi32" fn SelectObject(hdc: HDC, h: ?*anyopaque) callconv(.C) ?*anyopaque;
pub extern "gdi32" fn DeleteObject(ho: *anyopaque) callconv(.C) BOOL;
pub const GetModuleHandleW = w.kernel32.GetModuleHandleW;
pub extern "kernel32" fn LoadIconA(hInstance: ?w.HMODULE, lpIconName: [*:0]const u8) callconv(.C) ?HICON;
pub extern "shell32" fn Shell_NotifyIconA(dwMessage: DWORD, lpData: *NOTIFYICONDATAA) callconv(.C) BOOL;

pub fn getCursorPos() !POINT {
    var point: POINT = undefined;
    if (GetCursorPos(&point) == 0)
        return error.OperationFailed;
    return point;
}

pub fn getWindowRect(hwnd: HWND) !RECT {
    var rect: RECT = undefined;
    if (GetWindowRect(hwnd, &rect) == 0)
        return error.OperationFailed;
    return rect;
}
