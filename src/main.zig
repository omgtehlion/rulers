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
    // Use a simple approach - look for rulers.ini in current directory
    const ini_path = "rulers.ini";

    // if (std.fs.cwd().openFile(ini_path, .{})) |file| {
    //     defer file.close();

    //     const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    //     defer allocator.free(content);

    //     var lines = std.mem.splitScalar(u8, content, '\n');
    //     while (lines.next()) |line| {
    //         const trimmed = std.mem.trim(u8, line, " \r");
    //         if (trimmed.len == 0) continue;
    //         if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
    //             const name = trimmed[0..eq_pos];
    //             const value_str = trimmed[eq_pos + 1 ..];
    //             if (name.len > 0 and (name[0] == 'H' or name[0] == 'V')) {
    //                 const pos = std.fmt.parseInt(i32, value_str, 10) catch continue;
    //                 const is_vertical = name[0] == 'V';

    //                 // Find which monitor this position belongs to (or use primary if negative)
    //                 var target_monitor: ?win.MonitorInfo = null;
    //                 for (monitors) |monitor| {
    //                     const in_bounds = if (is_vertical)
    //                         pos >= monitor.rect.left and pos <= monitor.rect.right
    //                     else
    //                         pos >= monitor.rect.top and pos <= monitor.rect.bottom;

    //                     if (in_bounds) {
    //                         target_monitor = monitor;
    //                         break;
    //                     }
    //                 }

    //                 // If no monitor found (e.g., negative coordinates), use primary monitor
    //                 if (target_monitor == null) {
    //                     for (monitors) |monitor| {
    //                         if (monitor.is_primary) {
    //                             target_monitor = monitor;
    //                             break;
    //                         }
    //                     }
    //                 }

    //                 // If still no monitor found, use first monitor
    //                 if (target_monitor == null and monitors.len > 0) {
    //                     target_monitor = monitors[0];
    //                 }

    //                 if (target_monitor) |monitor| {
    //                     var guide = try Guide.create(allocator, is_vertical, monitor);
    //                     guide.move(pos);
    //                 }
    //             }
    //         }
    //     }
    // } else |_| {
    //     // File doesn't exist, that's okay
    // }

    globals.display_mode = 0;
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
