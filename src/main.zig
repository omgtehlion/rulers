const std = @import("std");
const win = @import("windows.zig");
const globals = @import("globals.zig");
const Guide = @import("guide.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();

    try globals.init(allocator);
    defer globals.deinit();

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
            }
        }
    } else |_| {
        // File doesn't exist, that's okay
    }

    globals.notifyAll();
    try globals.run();

    // Save guides to INI file
    var guides_content = std.ArrayList(u8).init(allocator);
    defer guides_content.deinit();
    try globals.dumpGuides(&guides_content);
    if (std.fs.cwd().createFile(ini_path, .{})) |file| {
        defer file.close();
        _ = try file.writeAll(guides_content.items);
    } else |_| {
        // Could not save file
    }
}
