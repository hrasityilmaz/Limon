const std = @import("std");
const builtin = @import("builtin");
const helpers = @import("../helper/helpers.zig");

pub const CpuTimes = struct {
    idle: u64 = 0,
    total: u64 = 0,
};

pub fn getCpuTimes() CpuTimes {
    var buf: [256]u8 = undefined;
    const n = readFile("/proc/stat", &buf) orelse return .{};
    const line = buf[0..n];

    var it = std.mem.tokenizeScalar(u8, line, ' ');
    _ = it.next();
    var vals: [10]u64 = [_]u64{0} ** 10;
    var i: usize = 0;
    while (it.next()) |tok| {
        const trimmed = std.mem.trim(u8, tok, "\n");
        if (trimmed.len == 0) break;
        vals[i] = std.fmt.parseInt(u64, trimmed, 10) catch 0;
        i += 1;
        if (i >= vals.len) break;
    }
    const idle = vals[3];
    var total: u64 = 0;
    for (vals[0..i]) |v| total += v;
    return .{ .idle = idle, .total = total };
}

pub const MemInfo = struct {
    used_gb: f64 = 0,
    total_gb: f64 = 0,
    pct: u64 = 0,
};

pub fn getMemInfo() MemInfo {
    var buf: [2048]u8 = undefined;
    const n = readFile("/proc/meminfo", &buf) orelse return .{};

    var mem_total: u64 = 0;
    var mem_available: u64 = 0;
    var it = std.mem.tokenizeScalar(u8, buf[0..n], '\n');
    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            var li = std.mem.tokenizeScalar(u8, line, ' ');
            _ = li.next();
            mem_total = std.fmt.parseInt(u64, li.next() orelse "0", 10) catch 0;
        } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
            var li = std.mem.tokenizeScalar(u8, line, ' ');
            _ = li.next();
            mem_available = std.fmt.parseInt(u64, li.next() orelse "0", 10) catch 0;
        }
    }
    const used_kb = mem_total -| mem_available;
    return .{
        .total_gb = @as(f64, @floatFromInt(mem_total)) / (1024 * 1024),
        .used_gb = @as(f64, @floatFromInt(used_kb)) / (1024 * 1024),
        .pct = if (mem_total > 0) (used_kb * 100) / mem_total else 0,
    };
}

pub fn getUptime() u64 {
    var buf: [64]u8 = undefined;
    const n = readFile("/proc/uptime", &buf) orelse return 0;
    var it = std.mem.tokenizeScalar(u8, buf[0..n], ' ');
    const secs_str = it.next() orelse return 0;
    const dot = std.mem.indexOfScalar(u8, secs_str, '.') orelse secs_str.len;
    return std.fmt.parseInt(u64, secs_str[0..dot], 10) catch 0;
}

pub fn getHostname(buf: []u8) usize {
    var uts: std.os.linux.utsname = undefined;
    const rc = std.os.linux.uname(&uts);
    if (rc != 0) return 0;
    const nodename: []const u8 = std.mem.sliceTo(&uts.nodename, 0);
    const len = @min(nodename.len, buf.len);
    @memcpy(buf[0..len], nodename[0..len]);
    return len;
}

pub fn getOsVer(buf: []u8) usize {
    var tmp: [1024]u8 = undefined;
    const n = readFile("/etc/os-release", &tmp) orelse return 0;
    var it = std.mem.tokenizeScalar(u8, tmp[0..n], '\n');
    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, "PRETTY_NAME=")) {
            const val = std.mem.trim(u8, line[12..], "\"");
            const len = @min(val.len, buf.len);
            @memcpy(buf[0..len], val[0..len]);
            return len;
        }
    }
    return 0;
}

pub fn getCores() u32 {
    var buf: [16384]u8 = undefined;
    const n = readFile("/proc/cpuinfo", &buf) orelse return 0;
    var count: u32 = 0;
    var it = std.mem.tokenizeScalar(u8, buf[0..n], '\n');
    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, "processor")) count += 1;
    }
    return count;
}

pub fn getDisks(out: []helpers.DiskInfo) usize {
    var buf: [4096]u8 = undefined;
    const n = readFile("/proc/mounts", &buf) orelse return 0;

    const skip_fs = [_][]const u8{ "tmpfs", "devtmpfs", "sysfs", "proc", "devpts", "cgroup", "cgroup2", "pstore", "bpf", "tracefs", "debugfs", "configfs", "fusectl", "hugetlbfs", "mqueue", "securityfs", "efivarfs", "autofs", "overlay", "squashfs", "ramfs", "rootfs", "9p", "plan9", "drvfs" };

    var seen_devs: [32]u64 = [_]u64{0} ** 32;
    var seen_count: usize = 0;

    var count: usize = 0;
    var it = std.mem.tokenizeScalar(u8, buf[0..n], '\n');
    while (it.next()) |line| {
        if (count >= out.len) break;
        var fi = std.mem.tokenizeScalar(u8, line, ' ');
        _ = fi.next();
        const mount = fi.next() orelse continue;
        const fstype = fi.next() orelse continue;

        var skip = false;
        for (skip_fs) |sf| {
            if (std.mem.eql(u8, fstype, sf)) {
                skip = true;
                break;
            }
        }
        if (skip) continue;
        if (!std.mem.startsWith(u8, mount, "/")) continue;
        const StatfsBuf = extern struct {
            f_type: i64,
            f_bsize: i64,
            f_blocks: u64,
            f_bfree: u64,
            f_bavail: u64,
            f_files: u64,
            f_ffree: u64,
            f_fsid: [2]i32,
            f_namelen: i64,
            f_frsize: i64,
            f_flags: i64,
            f_spare: [4]i64,
        };
        var stat: StatfsBuf = undefined;
        var mountBuf: [256]u8 = undefined;
        const mlen = @min(mount.len, mountBuf.len - 1);
        @memcpy(mountBuf[0..mlen], mount[0..mlen]);
        mountBuf[mlen] = 0;

        const rc = std.os.linux.syscall2(
            .statfs,
            @intFromPtr(@as([*:0]const u8, @ptrCast(&mountBuf))),
            @intFromPtr(&stat),
        );
        if (@as(isize, @bitCast(rc)) < 0) continue;
        const dev_id = @as(u64, @bitCast(stat.f_fsid));
        var already_seen = false;
        for (seen_devs[0..seen_count]) |d| {
            if (d == dev_id) {
                already_seen = true;
                break;
            }
        }
        if (already_seen) continue;
        if (seen_count < seen_devs.len) {
            seen_devs[seen_count] = dev_id;
            seen_count += 1;
        }

        const total = stat.f_blocks * @as(u64, @intCast(stat.f_frsize));
        const free_ = stat.f_bfree * @as(u64, @intCast(stat.f_frsize));
        if (total == 0) continue;
        const used = total - free_;

        var info = helpers.DiskInfo{};
        const ll = @min(mount.len, info.letter.len - 1);
        @memcpy(info.letter[0..ll], mount[0..ll]);
        info.used_gb = @as(f64, @floatFromInt(used)) / (1024 * 1024 * 1024);
        info.total_gb = @as(f64, @floatFromInt(total)) / (1024 * 1024 * 1024);
        info.pct = (used * 100) / total;
        out[count] = info;
        count += 1;
    }
    return count;
}

pub const NetStat = struct {
    rx: u64 = 0,
    tx: u64 = 0,
};

pub fn getNetStat(iface: []const u8) NetStat {
    var buf: [4096]u8 = undefined;
    const n = readFile("/proc/net/dev", &buf) orelse return .{};
    var it = std.mem.tokenizeScalar(u8, buf[0..n], '\n');
    _ = it.next();
    _ = it.next();
    while (it.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " ");
        if (!std.mem.startsWith(u8, trimmed, iface)) continue;
        var fi = std.mem.tokenizeScalar(u8, trimmed, ' ');
        _ = fi.next();
        const rx = std.fmt.parseInt(u64, fi.next() orelse "0", 10) catch 0;
        var s: usize = 0;
        while (s < 7) : (s += 1) _ = fi.next();
        const tx = std.fmt.parseInt(u64, fi.next() orelse "0", 10) catch 0;
        return .{ .rx = rx, .tx = tx };
    }
    return .{};
}

pub fn getDefaultIface(buf: []u8) []u8 {
    var tmp: [4096]u8 = undefined;
    const n = readFile("/proc/net/dev", &tmp) orelse return buf[0..0];
    var it = std.mem.tokenizeScalar(u8, tmp[0..n], '\n');
    _ = it.next();
    _ = it.next();
    while (it.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " ");
        const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
        const name = std.mem.trimEnd(u8, trimmed[0..colon], " ");
        if (std.mem.eql(u8, name, "lo")) continue;
        const len = @min(name.len, buf.len);
        @memcpy(buf[0..len], name[0..len]);
        return buf[0..len];
    }
    return buf[0..0];
}

pub fn getLocalIp(iface: []const u8, ipBuf: []u8) usize {
    const r = getLocalIpFromProc(ipBuf);
    if (r > 0) return r;
    return getLocalIpFromTcp(iface, ipBuf);
}

fn getLocalIpFromProc(ipBuf: []u8) usize {
    var buf: [65536]u8 = undefined;
    const n = readFile("/proc/net/fib_trie", &buf) orelse return 0;
    var lines = std.mem.tokenizeScalar(u8, buf[0..n], '\n');
    var last_ip_line: []const u8 = &.{};

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");

        if (std.mem.indexOf(u8, trimmed, "/32 host LOCAL") != null) {
            const ip = std.mem.trim(u8, last_ip_line, " \t");
            if (isIpLine(ip) and
                !std.mem.startsWith(u8, ip, "127.") and
                !std.mem.startsWith(u8, ip, "0.") and
                !std.mem.eql(u8, ip, "255.255.255.255"))
            {
                const len = @min(ip.len, ipBuf.len);
                @memcpy(ipBuf[0..len], ip[0..len]);
                return len;
            }
        }
        last_ip_line = line;
    }
    return 0;
}

fn isIpLine(s: []const u8) bool {
    if (s.len == 0) return false;
    var dots: usize = 0;
    for (s) |c| {
        if (c == '.') {
            dots += 1;
        } else if (c < '0' or c > '9') return false;
    }
    return dots == 3;
}

fn getLocalIpFromTcp(iface: []const u8, ipBuf: []u8) usize {
    _ = iface;
    var buf: [8192]u8 = undefined;
    const n = readFile("/proc/net/tcp", &buf) orelse return 0;
    var it = std.mem.tokenizeScalar(u8, buf[0..n], '\n');
    _ = it.next();
    while (it.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " ");
        var fi = std.mem.tokenizeScalar(u8, trimmed, ' ');
        _ = fi.next();
        const local = fi.next() orelse continue;
        const colon = std.mem.indexOfScalar(u8, local, ':') orelse continue;
        const hex = local[0..colon];
        if (hex.len != 8) continue;
        const raw = std.fmt.parseInt(u32, hex, 16) catch continue;
        const b0 = raw & 0xFF;
        const b1 = (raw >> 8) & 0xFF;
        const b2 = (raw >> 16) & 0xFF;
        const b3 = (raw >> 24) & 0xFF;
        if (b0 == 127 or raw == 0) continue;
        if (b0 == 10 and b1 == 255) continue;
        const s = std.fmt.bufPrint(ipBuf, "{}.{}.{}.{}", .{ b0, b1, b2, b3 }) catch continue;
        return s.len;
    }
    return 0;
}

pub fn getArchStr() []const u8 {
    return @tagName(builtin.cpu.arch);
}

fn readFile(comptime path: [:0]const u8, buf: []u8) ?usize {
    const linux = std.os.linux;
    const fd_raw = linux.syscall4(
        .openat,
        @as(usize, @bitCast(@as(isize, linux.AT.FDCWD))),
        @intFromPtr(path.ptr),
        0,
        0,
    );
    const fd: isize = @bitCast(fd_raw);
    if (fd < 0) return null;
    defer _ = linux.close(@intCast(fd));

    const nr = linux.read(@intCast(fd), buf.ptr, buf.len);
    const n: isize = @bitCast(nr);
    if (n <= 0) return null;
    return @intCast(n);
}
