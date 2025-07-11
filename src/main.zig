const std = @import("std");
const win = @import("windows.zig");
const globals = @import("globals.zig");
const Guide = @import("guide.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();

    const mutex = win.CreateMutexA(null, 1, "Global\\Rulers-ae565d49-98a8-4dee-975f-f79eaf8e0611") orelse return;
    defer _ = std.os.windows.CloseHandle(mutex);
    if (std.os.windows.GetLastError() == std.os.windows.Win32Error.ALREADY_EXISTS) {
        if (win.FindWindowA("RulersWndCls", null)) |existing|
            _ = win.PostMessageA(existing, globals.WM_BRING_TO_FRONT, 0, 0);
        return;
    }

    try globals.init(allocator);
    defer globals.deinit();
    try Guide.initializeStatics();

    // Load guides from INI file
    const ini_path = "rulers.ini";
    if (std.fs.cwd().openFile(ini_path, .{})) |file| {
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            var tokens = std.mem.tokenizeScalar(u8, std.mem.trim(u8, line, " \t\r"), '=');
            const name = tokens.next() orelse continue;
            const value = tokens.next() orelse continue;
            if (name.len > 0 and (name[0] == 'H' or name[0] == 'V')) {
                const pos = std.fmt.parseInt(i32, value, 10) catch continue;
                const vertical = name[0] == 'V';
                // Find which monitor this position belongs to
                var monitor: ?win.MonitorInfo = null;
                for (globals.getMonitors()) |m| {
                    const found = if (vertical) pos >= m.rect.left and pos < m.rect.right else pos >= m.rect.top and pos < m.rect.bottom;
                    if (found) {
                        monitor = m;
                        break;
                    }
                }
                if (monitor) |m|
                    (try Guide.create(allocator, vertical, m.rect)).move(pos);
            } else if (std.mem.eql(u8, name, "Mode")) {
                globals.display_mode = std.fmt.parseInt(u32, value, 10) catch 0;
            }
        }
    } else |_| {
        // File doesn't exist, that's okay
    }

    globals.notifyAll();
    try globals.run();

    if (std.fs.cwd().createFile(ini_path, .{})) |file| {
        defer file.close();
        // Save guides to INI file
        var content = std.ArrayList(u8).init(allocator);
        defer content.deinit();
        try globals.dumpGuides(&content);
        try content.writer().print("Mode={}\n", .{globals.display_mode});
        _ = try file.writeAll(content.items);
    } else |_| {
        // Could not save file
    }
}
