const std = @import("std");
const builtin = @import("builtin");

// TODO: Add way to format message.
fn fatalError(comptime message: []const u8) !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print(message, .{});
    std.posix.exit(1);
}

fn showHelp() !void {
    try fatalError("usage: open-repo [-h/--help] [-d/--dump-url]\n");
}

fn isGitRepo() std.fs.Dir.AccessError!bool {
    std.fs.cwd().access(".git", .{}) catch |err| {
        if (err == error.FileNotFound) {
            return false;
        }

        return err;
    };

    return true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("memleak\n");

    const allocator = gpa.allocator();

    const is_git_repo = isGitRepo() catch |err| {
        const stderr = std.io.getStdErr().writer();
        stderr.print("Unable to open .git folder: {s}\n", .{@errorName(err)}) catch return;
        return std.posix.exit(1);
    };

    if (!is_git_repo) {
        return try fatalError("This folder is not a git repository\n");
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const Flags = struct {
        dump_url: bool = false,
    };

    var flags = Flags{};

    for (args) |arg| {
        if (arg[0] == '-') {
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                return try showHelp();
            }

            if (std.mem.eql(u8, arg, "--dump-arg") or std.mem.eql(u8, arg, "-d")) {
                flags.dump_url = true;
            }
        }
    }

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

            // remove .git only if found in element.
            route = route: {
                if (std.mem.endsWith(u8, element, suffix)) {
                    break :route try allocator.dupe(u8, element[0 .. element.len - suffix.len]);
                }

                break :route try allocator.dupe(u8, element[0..]);
            };
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

    if (flags.dump_url) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s}\n", .{final_url});
        return std.posix.exit(0);
    }

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
