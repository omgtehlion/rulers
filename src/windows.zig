const std = @import("std");
const w = std.os.windows;

pub const HWND = w.HWND;
pub const HDC = w.HDC;
pub const HMENU = w.HMENU;
pub const HICON = w.HICON;
pub const HBITMAP = *opaque {};
pub const HBRUSH = w.HBRUSH;
pub const HHOOK = *opaque {};
pub const HANDLE = w.HANDLE;
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
    hCursor: ?HANDLE,
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
pub const MONITORINFO = extern struct {
    cbSize: DWORD,
    rcMonitor: RECT,
    rcWork: RECT,
    dwFlags: DWORD,
};
pub const HMONITOR = *opaque {};

pub const MENUITEMINFOA = extern struct {
    cbSize: UINT,
    fMask: UINT,
    fType: UINT,
    fState: UINT,
    wID: UINT,
    hSubMenu: ?HMENU,
    hbmpChecked: ?HBITMAP,
    hbmpUnchecked: ?HBITMAP,
    dwItemData: ULONG_PTR,
    dwTypeData: ?[*:0]u8,
    cch: UINT,
    hbmpItem: ?HBITMAP,
};

pub const BITMAPV5HEADER = extern struct {
    bV5Size: DWORD,
    bV5Width: c_long,
    bV5Height: c_long,
    bV5Planes: WORD,
    bV5BitCount: WORD,
    bV5Compression: DWORD,
    bV5SizeImage: DWORD,
    bV5XPelsPerMeter: c_long,
    bV5YPelsPerMeter: c_long,
    bV5ClrUsed: DWORD,
    bV5ClrImportant: DWORD,
    bV5RedMask: DWORD,
    bV5GreenMask: DWORD,
    bV5BlueMask: DWORD,
    bV5AlphaMask: DWORD,
    bV5CSType: DWORD,
    bV5Endpoints: [36]u8, // CIEXYZTRIPLE
    bV5GammaRed: DWORD,
    bV5GammaGreen: DWORD,
    bV5GammaBlue: DWORD,
    bV5Intent: DWORD,
    bV5ProfileData: DWORD,
    bV5ProfileSize: DWORD,
    bV5Reserved: DWORD,
};

pub const WM_NULL = 0x0000;
pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_MOVE = 0x0003;
pub const WM_SIZE = 0x0005;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_COMMAND = 0x0111;
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
pub const WM_DISPLAYCHANGE = 0x007E;
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
pub const HWND_NOTOPMOST = @as(HWND, @ptrFromInt(@as(usize, @bitCast(@as(isize, -2)))));

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

pub const MONITORINFOF_PRIMARY = 0x00000001;

pub const MF_STRING = 0x00000000;
pub const MF_GRAYED = 0x00000001;
pub const MF_SEPARATOR = 0x00000800;
pub const MF_CHECKED = 0x00000008;
pub const MF_UNCHECKED = 0x00000000;
pub const MFT_RADIOCHECK = 0x00000200;
pub const MFS_CHECKED = 0x00000008;
pub const MFS_UNCHECKED = 0x00000000;
pub const MIIM_TYPE = 0x00000010;
pub const MIIM_STATE = 0x00000001;
pub const MIIM_ID = 0x00000002;
pub const MIIM_STRING = 0x00000040;
pub const MIIM_FTYPE = 0x00000100;
pub const TPM_RIGHTBUTTON = 0x0002;
pub const TPM_RETURNCMD = 0x0100;

pub const BI_RGB = 0;
pub const DIB_RGB_COLORS = 0;
pub const LCS_WINDOWS_COLOR_SPACE = 0x57696E20; // 'Win '

pub const IMAGE_CURSOR = 2;
pub const LR_DEFAULTSIZE = 0x00000040;
pub const LR_LOADFROMFILE = 0x00000010;
pub const LR_SHARED = 0x00008000;

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
pub extern "user32" fn UpdateLayeredWindow(hWnd: HWND, hdcDst: ?HDC, pptDst: ?*const POINT, psize: ?*const SIZE, hdcSrc: HDC, pptSrc: ?*const POINT, crKey: DWORD, pblend: ?*const BLENDFUNCTION, dwFlags: DWORD) callconv(.C) BOOL;
pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(.C) ?HDC;
pub extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.C) c_int;
pub extern "user32" fn GetDesktopWindow() callconv(.C) HWND;
pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.C) BOOL;
pub extern "user32" fn SetWindowPos(hWnd: HWND, hWndInsertAfter: ?HWND, X: c_int, Y: c_int, cx: c_int, cy: c_int, uFlags: UINT) callconv(.C) BOOL;
pub extern "user32" fn SetWindowLongPtrA(hWnd: HWND, nIndex: c_int, dwNewLong: LONG_PTR) callconv(.C) LONG_PTR;
pub extern "user32" fn GetWindowLongPtrA(hWnd: HWND, nIndex: c_int) callconv(.C) LONG_PTR;
pub extern "user32" fn SetWindowLongA(hWnd: HWND, nIndex: c_int, dwNewLong: c_long) callconv(.C) c_long;
pub extern "user32" fn GetWindowLongA(hWnd: HWND, nIndex: c_int) callconv(.C) c_long;
pub extern "user32" fn LoadCursorA(hInstance: ?w.HMODULE, lpCursorName: [*:0]const u8) callconv(.C) ?HANDLE;
pub extern "user32" fn LoadImageA(hInst: ?w.HMODULE, name: [*:0]const u8, type: UINT, cx: c_int, cy: c_int, fuLoad: UINT) callconv(.C) ?HANDLE;
pub extern "user32" fn SetCursor(hCursor: ?HANDLE) callconv(.C) ?HANDLE;
pub extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.C) BOOL;
pub extern "user32" fn SetForegroundWindow(hWnd: HWND) callconv(.C) BOOL;
pub extern "user32" fn PostMessageA(hWnd: ?HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.C) BOOL;
pub extern "user32" fn WaitMessage() callconv(.C) BOOL;
pub extern "user32" fn SetWindowsHookExA(idHook: c_int, lpfn: *const fn (c_int, WPARAM, LPARAM) callconv(.C) LRESULT, hMod: w.HMODULE, dwThreadId: DWORD) callconv(.C) ?HHOOK;
pub extern "user32" fn UnhookWindowsHookEx(hhk: HHOOK) callconv(.C) BOOL;
pub extern "user32" fn CallNextHookEx(hhk: ?HHOOK, nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(.C) LRESULT;
pub extern "user32" fn EnumDisplayMonitors(hdc: ?HDC, lprcClip: ?*RECT, lpfnEnum: *const fn (HMONITOR, HDC, *RECT, LPARAM) callconv(.C) BOOL, dwData: LPARAM) callconv(.C) BOOL;
pub extern "user32" fn GetMonitorInfoA(hMonitor: HMONITOR, lpmi: *MONITORINFO) callconv(.C) BOOL;
pub extern "user32" fn CreatePopupMenu() callconv(.C) ?HMENU;
pub extern "user32" fn AppendMenuA(hMenu: HMENU, uFlags: UINT, uIDNewItem: ULONG_PTR, lpNewItem: ?[*:0]const u8) callconv(.C) BOOL;
pub extern "user32" fn InsertMenuItemA(hmenu: HMENU, item: UINT, fByPosition: BOOL, lpmi: *const MENUITEMINFOA) callconv(.C) BOOL;
pub extern "user32" fn SetMenuItemInfoA(hmenu: HMENU, item: UINT, fByPosition: BOOL, lpmii: *const MENUITEMINFOA) callconv(.C) BOOL;
pub extern "user32" fn TrackPopupMenu(hMenu: HMENU, uFlags: UINT, x: c_int, y: c_int, nReserved: c_int, hWnd: HWND, prcRect: ?*const RECT) callconv(.C) BOOL;
pub extern "user32" fn DestroyMenu(hMenu: HMENU) callconv(.C) BOOL;
pub extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.C) ?HDC;
pub extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.C) BOOL;
pub extern "gdi32" fn SelectObject(hdc: HDC, h: ?*anyopaque) callconv(.C) ?*anyopaque;
pub extern "gdi32" fn DeleteObject(ho: *anyopaque) callconv(.C) BOOL;
pub extern "gdi32" fn CreateDIBSection(hdc: ?HDC, lpbmi: *const BITMAPV5HEADER, usage: UINT, ppvBits: *?*anyopaque, hSection: ?HANDLE, offset: DWORD) callconv(.C) ?HBITMAP;
pub const GetModuleHandleW = w.kernel32.GetModuleHandleW;
pub extern "kernel32" fn LoadIconA(hInstance: ?w.HMODULE, lpIconName: [*:0]const u8) callconv(.C) ?HICON;
pub extern "kernel32" fn CreateMutexA(lpMutexAttributes: ?*anyopaque, bInitialOwner: BOOL, lpName: ?[*:0]const u8) callconv(.C) ?HANDLE;
pub extern "kernel32" fn FindWindowA(lpClassName: ?[*:0]const u8, lpWindowName: ?[*:0]const u8) callconv(.C) ?HWND;
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

pub const MonitorInfo = struct {
    rect: RECT,
    work_rect: RECT,
    is_primary: bool,
};

pub fn enumMonitors(allocator: std.mem.Allocator) ![]MonitorInfo {
    var monitors = std.ArrayList(MonitorInfo).init(allocator);
    const EnumContext = struct {
        fn enumProc(hMonitor: HMONITOR, hdc: HDC, lprcMonitor: *RECT, dwData: LPARAM) callconv(.C) BOOL {
            _ = hdc;
            _ = lprcMonitor;
            const m: *std.ArrayList(MonitorInfo) = @ptrFromInt(@as(usize, @bitCast(dwData)));
            var mi = MONITORINFO{ .cbSize = @sizeOf(MONITORINFO), .rcMonitor = undefined, .rcWork = undefined, .dwFlags = 0 };
            if (GetMonitorInfoA(hMonitor, &mi) != 0)
                m.append(.{ .rect = mi.rcMonitor, .work_rect = mi.rcWork, .is_primary = (mi.dwFlags & MONITORINFOF_PRIMARY) != 0 }) catch return 0;
            return 1; // Continue enumeration
        }
    };
    if (EnumDisplayMonitors(null, null, EnumContext.enumProc, @bitCast(@intFromPtr(&monitors))) == 0) {
        monitors.deinit();
        return error.OperationFailed;
    }
    return monitors.toOwnedSlice();
}
