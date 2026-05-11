const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const helpers = @import("helper/helpers.zig");

const tag = builtin.os.tag;

pub var gStats = helpers.Stats{};

const APP_NAME: [:0]const u8 = "LIMON";
const VERSION = "⁰·¹";

pub fn visualLen(s: []const u8) usize {
    return std.unicode.utf8CountCodepoints(s) catch s.len;
}

pub fn spaces(w: *Io.Writer, n: usize) !void {
    var buf: [64]u8 = @splat(' ');
    var rem = n;
    while (rem > 0) {
        const chunk = @min(rem, buf.len);
        _ = try w.write(buf[0..chunk]);
        rem -= chunk;
    }
}

const windows_collector = if (tag == .windows) struct {
    const win = @import("win/win.zig");
    const types = @import("win/types.zig");

    fn getIpAndLuid(ipBuf: []u8, luid: *u64) usize {
        var addrBuf: [16384]u8 align(@alignOf(types.IP_ADAPTER_ADDRESSES)) = undefined;
        var size: u32 = addrBuf.len;
        const ret = win.GetAdaptersAddresses(2, 0x10, null, @ptrCast(&addrBuf), &size);
        if (ret != 0) return 0;
        var adapter: ?*types.IP_ADAPTER_ADDRESSES = @ptrCast(&addrBuf);
        while (adapter) |a| {
            if (a.OperStatus == 1 and
                (a.IfType == 6 or a.IfType == 71) and
                a.PhysicalAddressLength > 0)
            {
                var uni = a.FirstUnicastAddress;
                while (uni) |u| {
                    if (u.Address.lpSockaddr) |sa| {
                        if (sa.sa_family == 2) {
                            const ip_bytes = sa.sa_data[2..6];
                            const b0 = ip_bytes[0];
                            const b1 = ip_bytes[1];
                            const is_loopback = b0 == 127;
                            const is_wsl = b0 == 172 and b1 >= 16 and b1 <= 31;
                            const is_link_local = b0 == 169 and b1 == 254;
                            if (!is_loopback and !is_wsl and !is_link_local) {
                                _ = win.inet_ntop(2, ip_bytes.ptr, ipBuf.ptr, @intCast(ipBuf.len));
                                luid.* = a.Luid;
                                return std.mem.indexOfScalar(u8, ipBuf, 0) orelse 0;
                            }
                        }
                    }
                    uni = u.Next;
                }
            }
            adapter = a.Next;
        }
        return 0;
    }

    pub fn run(io: Io) !void {
        var idle1 = types.FILETIME{};
        var kernel1 = types.FILETIME{};
        var user1 = types.FILETIME{};
        _ = win.GetSystemTimes(&idle1, &kernel1, &user1);

        {
            try gStats.mutex.lock(io);
            defer gStats.mutex.unlock(io);

            var hostBufW: [256]u16 = undefined;
            var hostLen: u32 = 256;
            _ = win.GetComputerNameExW(0, &hostBufW, &hostLen);
            const utf8len = try std.unicode.utf16LeToUtf8(&gStats.hostname, hostBufW[0..hostLen]);
            gStats.hostnamt_len = @intCast(utf8len);

            var si = types.SYSTEM_INFO{};
            win.GetSystemInfo(&si);
            gStats.cores = si.dwNumberOfProcessors;
            gStats.arch = si.wProcesssorArchitecture;

            var osv = types.OSVERSIONINFOW{};
            _ = win.RtlGetVersion(&osv);
            const ver: []const u8 = if (osv.dwBuildNumber >= 22000)
                "Windows 11"
            else if (osv.dwBuildNumber >= 10240)
                "Windows 10"
            else
                "Windows";
            @memcpy(gStats.os_ver[0..ver.len], ver);
            gStats.os_ver_len = ver.len;

            gStats.ip_len = getIpAndLuid(&gStats.ip, &gStats.net_luid);
            gStats.connected = gStats.ip_len > 0;
        }

        var row1 = types.MIB_IF_ROW2{};
        row1.setLuid(gStats.net_luid);
        _ = win.GetIfEntry2(@ptrCast(&row1.buf));
        var t1 = win.GetTickCount64();

        while (gStats.running.load(.acquire)) {
            io.sleep(.fromMilliseconds(100), .awake) catch {};

            const t2 = win.GetTickCount64();
            const elapsed_ms = t2 - t1;
            t1 = t2;

            var idle2 = types.FILETIME{};
            var kernel2 = types.FILETIME{};
            var user2 = types.FILETIME{};
            _ = win.GetSystemTimes(&idle2, &kernel2, &user2);

            const idle = helpers.floatToU64(@bitCast(idle2)) - helpers.floatToU64(@bitCast(idle1));
            const total = (helpers.floatToU64(@bitCast(kernel2)) - helpers.floatToU64(@bitCast(kernel1))) + (helpers.floatToU64(@bitCast(user2)) - helpers.floatToU64(@bitCast(user1)));
            const cpu = if (total > 0) ((total - idle) * 100) / total else 0;
            idle1 = idle2;
            kernel1 = kernel2;
            user1 = user2;

            var mem = types.MEMORYSTATUSEX{};
            _ = win.GlobalMemoryStatusEx(&mem);
            const used_gb = @as(f64, @floatFromInt(mem.ullTotalPhys - mem.ullAvailPhys)) / (1024 * 1024 * 1024);
            const total_gb = @as(f64, @floatFromInt(mem.ullTotalPhys)) / (1024 * 1024 * 1024);
            const ram_pct = if (mem.ullTotalPhys > 0)
                ((mem.ullTotalPhys - mem.ullAvailPhys) * 100) / mem.ullTotalPhys
            else
                0;

            const uptime = win.GetTickCount64() / 1000;

            var driveBuf: [256]u8 = undefined;
            const driveLen = win.GetLogicalDriveStringsA(256, &driveBuf);
            var newDisks: [helpers.MAX_DISKS]helpers.DiskInfo = [_]helpers.DiskInfo{.{}} ** helpers.MAX_DISKS;
            var diskCount: usize = 0;
            var i: usize = 0;
            while (i < driveLen and diskCount < helpers.MAX_DISKS) {
                const slice = driveBuf[i..driveLen];
                const end = std.mem.indexOfScalar(u8, slice, 0) orelse break;
                if (end == 0) break;
                const driveStr = slice[0 .. end + 1];
                var dfree: u64 = 0;
                var dtotal: u64 = 0;
                var dtfree: u64 = 0;
                const ok = win.GetDiskFreeSpaceExA(@ptrCast(driveStr.ptr), &dfree, &dtotal, &dtfree);
                if (ok != .FALSE and dtotal > 0) {
                    var info = helpers.DiskInfo{};
                    const cl = @min(end, info.letter.len - 1);
                    @memcpy(info.letter[0..cl], driveStr[0..cl]);
                    info.used_gb = @as(f64, @floatFromInt(dtotal - dfree)) / (1024 * 1024 * 1024);
                    info.total_gb = @as(f64, @floatFromInt(dtotal)) / (1024 * 1024 * 1024);
                    info.pct = ((dtotal - dfree) * 100) / dtotal;
                    newDisks[diskCount] = info;
                    diskCount += 1;
                }
                i += end + 1;
            }

            var row2 = types.MIB_IF_ROW2{};
            row2.setLuid(gStats.net_luid);
            _ = win.GetIfEntry2(@ptrCast(&row2.buf));

            const down_bps = if (elapsed_ms > 0)
                (row2.getInOctets() -| row1.getInOctets()) * 1000 / elapsed_ms
            else
                0;
            const up_bps = if (elapsed_ms > 0)
                (row2.getOutOctets() -| row1.getOutOctets()) * 1000 / elapsed_ms
            else
                0;
            row1 = row2;

            var newIp: [46]u8 = [_]u8{0} ** 46;
            var newLuid: u64 = 0;
            const newIpLen = getIpAndLuid(&newIp, &newLuid);

            try gStats.mutex.lock(io);
            gStats.cpu_pct = cpu;
            gStats.ram_used_gb = used_gb;
            gStats.ram_total_gb = total_gb;
            gStats.ram_pct = ram_pct;
            gStats.uptime_s = uptime;
            gStats.disks = newDisks;
            gStats.disk_count = diskCount;
            gStats.net_down = down_bps;
            gStats.net_up = up_bps;
            gStats.connected = newIpLen > 0;
            if (newIpLen > 0) {
                if (newLuid != gStats.net_luid) {
                    gStats.net_luid = newLuid;
                    row1.setLuid(newLuid);
                }
                @memcpy(gStats.ip[0..newIpLen], newIp[0..newIpLen]);
                gStats.ip_len = newIpLen;
            } else {
                gStats.ip_len = 0;
            }
            gStats.mutex.unlock(io);
        }
    }
} else struct {};

const linux_collector = if (tag == .linux) struct {
    const linux = @import("linux/linux.zig");

    pub fn run(io: Io) !void {
        {
            try gStats.mutex.lock(io);
            defer gStats.mutex.unlock(io);

            gStats.hostnamt_len = @intCast(linux.getHostname(&gStats.hostname));
            gStats.os_ver_len = linux.getOsVer(&gStats.os_ver);
            gStats.arch = 0;
            gStats.cores = linux.getCores();

            var ifaceBuf: [16]u8 = undefined;
            const iface = linux.getDefaultIface(&ifaceBuf);
            const ipLen = linux.getLocalIp(iface, &gStats.ip);
            gStats.ip_len = ipLen;
            gStats.connected = ipLen > 0;
        }

        var ifaceBuf: [16]u8 = undefined;
        const iface = linux.getDefaultIface(&ifaceBuf);
        var prevNet = linux.getNetStat(iface);
        var prevCpu = linux.getCpuTimes();

        var ts1: std.os.linux.timespec = undefined;
        _ = std.os.linux.clock_gettime(std.os.linux.CLOCK.MONOTONIC, &ts1);

        while (gStats.running.load(.acquire)) {
            io.sleep(.fromMilliseconds(100), .awake) catch {};

            var ts2: std.os.linux.timespec = undefined;
            _ = std.os.linux.clock_gettime(std.os.linux.CLOCK.MONOTONIC, &ts2);
            const elapsed_ms: u64 = @intCast(
                (@as(i64, ts2.sec) - @as(i64, ts1.sec)) * 1000 +
                    @divTrunc(@as(i64, ts2.nsec) - @as(i64, ts1.nsec), 1_000_000),
            );
            ts1 = ts2;

            const curCpu = linux.getCpuTimes();
            const dIdle = curCpu.idle -| prevCpu.idle;
            const dTotal = curCpu.total -| prevCpu.total;
            const cpu = if (dTotal > 0) ((dTotal - dIdle) * 100) / dTotal else 0;
            prevCpu = curCpu;

            const mem = linux.getMemInfo();

            const uptime = linux.getUptime();

            var newDisks: [helpers.MAX_DISKS]helpers.DiskInfo = [_]helpers.DiskInfo{.{}} ** helpers.MAX_DISKS;
            const diskCount = linux.getDisks(&newDisks);

            const curNet = linux.getNetStat(iface);
            const down_bps = if (elapsed_ms > 0)
                (curNet.rx -| prevNet.rx) * 1000 / elapsed_ms
            else
                0;
            const up_bps = if (elapsed_ms > 0)
                (curNet.tx -| prevNet.tx) * 1000 / elapsed_ms
            else
                0;
            prevNet = curNet;

            var newIp: [46]u8 = [_]u8{0} ** 46;
            const newIpLen = linux.getLocalIp(iface, &newIp);

            try gStats.mutex.lock(io);
            gStats.cpu_pct = cpu;
            gStats.ram_used_gb = mem.used_gb;
            gStats.ram_total_gb = mem.total_gb;
            gStats.ram_pct = mem.pct;
            gStats.uptime_s = uptime;
            gStats.disks = newDisks;
            gStats.disk_count = diskCount;
            gStats.net_down = down_bps;
            gStats.net_up = up_bps;
            gStats.connected = newIpLen > 0;
            if (newIpLen > 0) {
                @memcpy(gStats.ip[0..newIpLen], newIp[0..newIpLen]);
                gStats.ip_len = newIpLen;
            } else {
                gStats.ip_len = 0;
            }
            gStats.mutex.unlock(io);
        }
    }
} else struct {};

pub fn collector(io: Io) !void {
    switch (tag) {
        .windows => try windows_collector.run(io),
        .linux => try linux_collector.run(io),
        else => @compileError("Unsupported OS"),
    }
}

pub fn render(io: Io, aw: *Io.Writer.Allocating) !void {
    aw.clearRetainingCapacity();
    const w = &aw.writer;

    try gStats.mutex.lock(io);
    const cpu = gStats.cpu_pct;
    const ramU = gStats.ram_used_gb;
    const ramT = gStats.ram_total_gb;
    const ramP = gStats.ram_pct;
    const upS = gStats.uptime_s;
    const hn = gStats.hostname[0..gStats.hostnamt_len];
    const cores = gStats.cores;
    const disks = gStats.disks;
    const diskCount = gStats.disk_count;
    const osVer = gStats.os_ver[0..gStats.os_ver_len];
    const connected = gStats.connected;
    const net_down = gStats.net_down;
    const net_up = gStats.net_up;
    var ipBuf: [46]u8 = [_]u8{0} ** 46;
    @memcpy(ipBuf[0..gStats.ip_len], gStats.ip[0..gStats.ip_len]);
    const ipLen = gStats.ip_len;
    gStats.mutex.unlock(io);

    const days = upS / 86400;
    const hours = (upS % 86400) / 3600;
    const mins = (upS % 3600) / 60;
    const secs = upS % 60;

    const W = 64;
    const LINE = "─" ** W;
    const TITLE_BAR = " " ** (W - 8);

    const archStr: []const u8 = switch (tag) {
        .windows => @tagName(@as(helpers.WinArch, @enumFromInt(gStats.arch))),
        .linux => @tagName(builtin.cpu.arch),
        else => "unknown",
    };
    var archBuf: [32]u8 = undefined;
    const arch = std.fmt.bufPrint(&archBuf, "{s} / {d}c", .{ archStr, cores }) catch archStr;

    try w.print("{s}┌{s}┐{s}\n", .{ helpers.BOLD, LINE, helpers.BOLD });
    try w.print("{s}│{s}{s}{s}{s}{s}{s}{s}│\n", .{ helpers.BOLD, helpers.RESET, helpers.YELLOW, helpers.BOLD, APP_NAME, VERSION, helpers.RESET, TITLE_BAR });
    try w.print("{s}└{s}┘{s}\n", .{ helpers.BOLD, LINE, helpers.BOLD });

    try w.print("{s}│{s}", .{ helpers.LIGHT, helpers.RESET });
    try spaces(w, W);
    try w.print("{s}│{s}\n", .{ helpers.LIGHT, helpers.RESET });

    try w.print("{s}│{s} {s}hostname{s} {s}{s}{s}", .{ helpers.LIGHT, helpers.RESET, helpers.LIGHT, helpers.RESET, helpers.CYAN, hn, helpers.RESET });
    try spaces(w, 22 -| visualLen(hn));
    try w.print("{s}cpu   {s}", .{ helpers.LIGHT, helpers.RESET });
    try helpers.drawBar(w, cpu, 18);
    try w.print(" {s}│{s}\n", .{ helpers.LIGHT, helpers.RESET });

    try w.print("{s}│{s} {s}os      {s} {s}{s}{s}", .{ helpers.LIGHT, helpers.RESET, helpers.LIGHT, helpers.RESET, helpers.CYAN, osVer, helpers.RESET });
    try spaces(w, 22 -| visualLen(osVer));
    try w.print("{s}ram   {s}", .{ helpers.LIGHT, helpers.RESET });
    try helpers.drawBar(w, ramP, 18);
    try w.print(" {s}│{s}\n", .{ helpers.LIGHT, helpers.RESET });

    var ramGbBuf: [24]u8 = undefined;
    const ramGb = std.fmt.bufPrint(&ramGbBuf, "{d:.1}GB / {d:.1}GB", .{ ramU, ramT }) catch "?";
    try w.print("{s}│{s} {s}arch    {s} {s}{s}{s}", .{ helpers.LIGHT, helpers.RESET, helpers.LIGHT, helpers.RESET, helpers.CYAN, arch, helpers.RESET });
    try spaces(w, 22 -| arch.len);
    try w.print("{s}      {s}{s}{s}{s}", .{ helpers.LIGHT, helpers.RESET, helpers.YELLOW, ramGb, helpers.RESET });
    try spaces(w, 26 -| ramGb.len);
    try w.print("{s}│{s}\n", .{ helpers.LIGHT, helpers.RESET });

    try w.print("{s}├{s}┤{s}\n", .{ helpers.LIGHT, LINE, helpers.RESET });

    var uptBuf: [24]u8 = undefined;
    const upt = std.fmt.bufPrint(&uptBuf, "{d}d {d:0>2}h {d:0>2}m {d:0>2}s", .{ days, hours, mins, secs }) catch "?";

    for (0..diskCount) |di| {
        const disk = disks[di];
        const letter = std.mem.sliceTo(&disk.letter, 0);
        // shorten..
        var shortLetterBuf: [6]u8 = undefined;
        const shortLetter: []const u8 = if (letter.len > 3) blk: {
            @memcpy(shortLetterBuf[0..3], letter[0..3]);
            shortLetterBuf[3] = '.';
            shortLetterBuf[4] = '.';
            break :blk shortLetterBuf[0..6];
        } else letter;

        if (di == 0) {
            try w.print("{s}│{s} {s}uptime  {s} {s}{s}{s}", .{ helpers.LIGHT, helpers.RESET, helpers.LIGHT, helpers.RESET, helpers.YELLOW, upt, helpers.RESET });
            try spaces(w, 22 -| upt.len);
        } else {
            try w.print("{s}│{s}", .{ helpers.LIGHT, helpers.RESET });
            try spaces(w, 32);
        }

        try w.print("{s}{s}{s}", .{ helpers.LIGHT, shortLetter, helpers.RESET });
        try spaces(w, 5 -| shortLetter.len);
        try helpers.drawBar(w, disk.pct, 19);
        try w.print(" {s}│{s}\n", .{ helpers.LIGHT, helpers.RESET });

        var gbBuf: [24]u8 = undefined;
        const gb = std.fmt.bufPrint(&gbBuf, "{d:.0}GB / {d:.0}GB", .{ disk.used_gb, disk.total_gb }) catch "?";
        try w.print("{s}│{s}", .{ helpers.LIGHT, helpers.RESET });
        try spaces(w, 38);
        try w.print("{s}{s}{s}", .{ helpers.BLUE, gb, helpers.RESET });
        try spaces(w, 26 -| gb.len);
        try w.print("{s}│{s}\n", .{ helpers.LIGHT, helpers.RESET });
    }

    try w.print("{s}├{s}┤{s}\n", .{ helpers.LIGHT, LINE, helpers.RESET });

    const ip = ipBuf[0..ipLen];
    if (connected) {
        try w.print("{s}│{s} {s}ip      {s} {s}{s}{s}", .{ helpers.LIGHT, helpers.RESET, helpers.LIGHT, helpers.RESET, helpers.CYAN, ip, helpers.RESET });
        try spaces(w, 22 -| visualLen(ip));
    } else {
        try w.print("{s}│{s} {s}ip      {s} {s}not connected{s}", .{ helpers.LIGHT, helpers.RESET, helpers.LIGHT, helpers.RESET, helpers.RED, helpers.RESET });
        try spaces(w, 9);
    }

    var downBuf: [16]u8 = undefined;
    var upBuf: [16]u8 = undefined;
    const downStr = helpers.fmtSpeed(&downBuf, net_down);
    const upStr = helpers.fmtSpeed(&upBuf, net_up);

    try w.print("{s}↓{s}{s}{s}", .{ helpers.GREEN, helpers.RESET, helpers.GREEN, downStr });
    try spaces(w, 12 -| downStr.len);
    try w.print("{s}{s}↑{s}{s}{s}", .{ helpers.RESET, helpers.YELLOW, helpers.RESET, helpers.YELLOW, upStr });
    try spaces(w, 18 -| upStr.len);
    try w.print("{s}{s}│{s}\n", .{ helpers.RESET, helpers.LIGHT, helpers.RESET });

    try w.print("{s}├{s}┤{s}\n", .{ helpers.LIGHT, LINE, helpers.RESET });
    try w.print("{s}│{s} {s}q: exit{s}", .{ helpers.LIGHT, helpers.RESET, helpers.LIGHT, helpers.RESET });
    try spaces(w, W - 8);
    try w.print("{s}│{s}\n", .{ helpers.LIGHT, helpers.RESET });
    try w.print("{s}└{s}┘{s}\n", .{ helpers.LIGHT, LINE, helpers.RESET });

    var stdout_buf: [8192]u8 = undefined;
    var stdout_wr = Io.File.stdout().writer(io, &stdout_buf);
    try stdout_wr.interface.writeAll(aw.written());
    try stdout_wr.interface.flush();
}
