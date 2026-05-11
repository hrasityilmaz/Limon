const std = @import("std");
const Io = std.Io;
const Atomic = std.atomic.Value;

pub const RESET = "\x1b[0m";
pub const CYAN = "\x1b[96m";
pub const GREEN = "\x1b[92m";
pub const YELLOW = "\x1b[93m";
pub const RED = "\x1b[91m";
pub const BLUE = "\x1b[94m";
pub const LIGHT = "\x1b[2m";
pub const BOLD = "\x1b[1m";
pub const HIDE_CURSOR = "\x1b[?25l";
pub const SHOW_CURSOR = "\x1b[?25h";
pub const CLEAR_SCREEN = "\x1b[2J\x1b[H";

pub const MAX_DISKS = 8;

pub const DiskInfo = struct {
    letter: [8]u8 = [_]u8{0} ** 8,
    used_gb: f64 = 0,
    total_gb: f64 = 0,
    pct: u64 = 0,
};

pub const Stats = struct {
    mutex: Io.Mutex = .init,
    running: Atomic(bool) = .init(true),
    cpu_pct: u64 = 0,
    ram_used_gb: f64 = 0,
    ram_total_gb: f64 = 0,
    ram_pct: u64 = 0,
    uptime_s: u64 = 0,
    hostname: [256]u8 = [_]u8{0} ** 256,
    hostnamt_len: u32 = 0,
    cores: u32 = 0,
    arch: u32 = 0,
    os_ver: [32]u8 = [_]u8{0} ** 32,
    os_ver_len: usize = 0,
    disks: [MAX_DISKS]DiskInfo = [_]DiskInfo{.{}} ** MAX_DISKS,
    disk_count: usize = 0,
    ip: [46]u8 = [_]u8{0} ** 46,
    ip_len: usize = 0,
    connected: bool = false,
    net_up: u64 = 0,
    net_down: u64 = 0,
    net_luid: u64 = 0,
};

pub const WinArch = enum(u32) {
    intel = 0,
    mips = 1,
    alpha = 2,
    ppc = 3,
    shx = 4,
    arm = 5,
    ia64 = 6,
    alpha64 = 7,
    msil = 8,
    amd64 = 9,
    ia32_on_win64 = 10,
    neutral = 11,
    arm64 = 12,
    arm32_on_win64 = 13,
    ia32_on_arm64 = 14,
    unknown = 0xFFFF,
};

pub const FILETIME = extern struct {
    dwLowDateTime: u32 = 0,
    dwHighDateTime: u32 = 0,
};
pub fn floatToU64(ft: FILETIME) u64 {
    return (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
}

pub fn fmtSpeed(buf: []u8, bps: u64) []u8 {
    if (bps >= 1024 * 1024) {
        return std.fmt.bufPrint(buf, "{d:.1}MB/s", .{
            @as(f64, @floatFromInt(bps)) / (1024 * 1024),
        }) catch buf[0..0];
    } else if (bps >= 1024) {
        return std.fmt.bufPrint(buf, "{d:.1}KB/s", .{
            @as(f64, @floatFromInt(bps)) / 1024,
        }) catch buf[0..0];
    } else {
        return std.fmt.bufPrint(buf, "{d}B/s", .{bps}) catch buf[0..0];
    }
}

pub fn drawBar(w: *Io.Writer, pct: u64, width: usize) !void {
    const filled = (pct * width) / 100;
    const empty = width - filled;
    const color = if (pct < 50) GREEN else if (pct < 85) YELLOW else RED;

    try w.print("{s}[{s}", .{ LIGHT, RESET });
    for (0..filled) |_| try w.print("{s}█{s}", .{ color, RESET });
    try w.print("{s}", .{LIGHT});
    for (0..empty) |_| try w.print("░", .{});
    try w.print("]{s} {s}{d:>3}%{s}", .{ RESET, color, pct, RESET });
}
