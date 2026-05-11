const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const helpers = @import("helper/helpers.zig");
const adapter = @import("adapter.zig");
const tag = builtin.os.tag;

const platform = switch (tag) {
    .windows => @import("win/win.zig"),
    .linux => @import("linux/linux.zig"),
    else => @compileError("Unsupported OS"),
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var buf: [64]u8 = undefined;
    var out = Io.File.stdout().writer(io, &buf);
    try out.interface.print("{s}{s}", .{ helpers.HIDE_CURSOR, helpers.CLEAR_SCREEN });
    try out.interface.flush();
    defer {
        out.interface.print("{s}", .{helpers.SHOW_CURSOR}) catch {};
        out.interface.flush() catch {};
    }

    switch (tag) {
        .windows => {
            const types = @import("win/types.zig");
            const STD_HANDLE: u32 = @bitCast(@as(i32, -11));
            const hOut = platform.GetStdHandle(STD_HANDLE) orelse return error.NoHandle;
            var mode: u32 = 0;
            _ = platform.GetConsoleMode(hOut, &mode);
            _ = platform.SetConsoleMode(hOut, mode | 0x0004);
            _ = platform.SetConsoleOutputCP(65001);

            const STD_INPUT_HANDLE: u32 = @bitCast(@as(i32, -10));
            const hIn = platform.GetStdHandle(STD_INPUT_HANDLE) orelse return error.NoHandle;

            const t = try std.Thread.spawn(.{}, adapter.collector, .{io});
            defer {
                adapter.gStats.running.store(false, .release);
                t.join();
            }

            var aw: Io.Writer.Allocating = .init(gpa);
            defer aw.deinit();

            while (adapter.gStats.running.load(.acquire)) {
                _ = platform.SetConsoleCursorPosition(hOut, .{ .X = 0, .Y = 0 });
                try adapter.render(io, &aw);

                var i: usize = 0;
                while (i < 10) : (i += 1) {
                    var count: u32 = 0;
                    _ = platform.GetNumberOfConsoleInputEvents(hIn, &count);
                    if (count > 0) {
                        var rec = types.INPUT_RECORD{};
                        var read: u32 = 0;
                        _ = platform.ReadConsoleInputA(hIn, &rec, 1, &read);
                        if (rec.EventType == 1 and rec.Event.bKeyDown != 0) {
                            const ch: u8 = @truncate(rec.Event.uChar);
                            if (ch == 'q' or ch == 'Q') {
                                adapter.gStats.running.store(false, .release);
                                break;
                            }
                        }
                    }
                    try io.sleep(.fromMilliseconds(25), .awake);
                }
            }
        },

        .linux => {
            const linux = std.os.linux;
            const tty_path: [*:0]const u8 = "/dev/tty";
            const tty_fd_raw = linux.syscall3(
                .open,
                @intFromPtr(tty_path),
                @as(u32, @bitCast(linux.O{ .ACCMODE = .RDWR, .NOCTTY = true })),
                0,
            );
            const tty_fd: i32 = @intCast(@as(isize, @bitCast(tty_fd_raw)));
            if (tty_fd < 0) return error.OpenTtyFailed;
            defer _ = linux.close(@intCast(tty_fd));
            var orig_termios: linux.termios = undefined;
            if (linux.tcgetattr(@intCast(tty_fd), &orig_termios) != 0)
                return error.TcGetAttrFailed;

            defer _ = linux.tcsetattr(
                @intCast(tty_fd),
                linux.TCSA.NOW,
                &orig_termios,
            );

            var raw = orig_termios;
            raw.lflag.ECHO = false;
            raw.lflag.ICANON = false;
            raw.cc[@intFromEnum(linux.V.MIN)] = 0;
            raw.cc[@intFromEnum(linux.V.TIME)] = 1;
            if (linux.tcsetattr(@intCast(tty_fd), linux.TCSA.NOW, &raw) != 0)
                return error.TcSetAttrFailed;

            const t = try std.Thread.spawn(.{}, adapter.collector, .{io});
            defer {
                adapter.gStats.running.store(false, .release);
                t.join();
            }

            var aw: Io.Writer.Allocating = .init(gpa);
            defer aw.deinit();

            while (adapter.gStats.running.load(.acquire)) {
                var cbuf: [16]u8 = undefined;
                var cwr = Io.File.stdout().writer(io, &cbuf);
                try cwr.interface.print("\x1b[H", .{});
                try cwr.interface.flush();

                try adapter.render(io, &aw);

                var i: usize = 0;
                while (i < 10) : (i += 1) {
                    var ch: [1]u8 = undefined;
                    const nr = linux.read(@intCast(tty_fd), &ch, 1);
                    if (nr > 0 and (ch[0] == 'q' or ch[0] == 'Q')) {
                        adapter.gStats.running.store(false, .release);
                        break;
                    }
                    try io.sleep(.fromMilliseconds(25), .awake);
                }
            }
        },

        else => @compileError("Unsupported OS"),
    }
}
