const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("memleak\n");

    const allocator = gpa.allocator();
    const argv = [_][]const u8{ "git", "remote", "get-url", "origin" };

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
    });

    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    // remove \n
    const url = try allocator.dupe(u8, result.stdout[0 .. result.stdout.len - 1]);
    defer allocator.free(url);

    if (!std.mem.containsAtLeast(u8, url, 1, "http") and !std.mem.startsWith(u8, url, "git@")) {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Unable to obtain correct output from `git remote get-url origin`\n", .{});
        return;
    }

    const final_url = url: {
        if (!std.mem.startsWith(u8, url, "git@")) {
            break :url url;
        }

        var it = std.mem.tokenize(u8, url, ":");
        var i: u32 = 0;

        var hostname: ?[]u8 = null;
        var route: ?[]u8 = null;

        defer {
            if (hostname) |host| allocator.free(host);
            if (route) |rout| allocator.free(rout);
        }

        while (it.next()) |element| : (i += 1) processor: {
            if (i > 1) break :processor;

            if (i == 0) {
                const prefix = "git@";
                hostname = try allocator.dupe(u8, element[prefix.len..]);
                continue;
            }

            const suffix = ".git";
            route = try allocator.dupe(u8, element[0 .. element.len - suffix.len]);
        }

        std.debug.assert(hostname != null and route != null);

        const new_url = try std.fmt.allocPrint(allocator, "https://{s}/{s}", .{
            hostname.?,
            route.?,
        });

        break :url new_url;
    };

    defer if (!std.mem.eql(u8, final_url, url)) {
        allocator.free(final_url);
    };

    const open_on_browser = [_][]const u8{ "xdg-open", final_url };

    const open_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &open_on_browser,
    });

    defer {
        allocator.free(open_result.stdout);
        allocator.free(open_result.stderr);
    }

    std.debug.print("Opening {s}...\n", .{final_url});
}
