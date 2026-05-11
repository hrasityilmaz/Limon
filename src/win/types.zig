const std = @import("std");

// structs for calls

//typedef struct _FILETIME {
//   DWORD dwLowDateTime;
//   DWORD dwHighDateTime;
// } FILETIME, *PFILETIME, *LPFILETIME;
//
pub const FILETIME = extern struct {
    dwLowDateTime: u32 = 0,
    dwHighDateTime: u32 = 0,
};

//typedef struct _SYSTEM_INFO {
//   union {
//     DWORD dwOemId;
//     struct {
//       WORD wProcessorArchitecture;
//       WORD wReserved;
//     } DUMMYSTRUCTNAME;
//   } DUMMYUNIONNAME;
//   DWORD     dwPageSize;
//   LPVOID    lpMinimumApplicationAddress;
//   LPVOID    lpMaximumApplicationAddress;
//   DWORD_PTR dwActiveProcessorMask;
//   DWORD     dwNumberOfProcessors;
//   DWORD     dwProcessorType;
//   DWORD     dwAllocationGranularity;
//   WORD      wProcessorLevel;
//   WORD      wProcessorRevision;
// } SYSTEM_INFO, *LPSYSTEM_INFO;
pub const SYSTEM_INFO = extern struct {
    wProcesssorArchitecture: u16 = 0,
    wReserved: u16 = 0,
    dwPageSize: u32 = 0,
    lpMimimumApplicationAddress: ?*anyopaque = null,
    lpMaximumApplicationAddress: ?*anyopaque = null,
    dwActiveProcessorMask: usize = 0,
    dwNumberOfProcessors: u32 = 0,
    dwProcessorType: u32 = 0,
    dwAllocationGranularity: u32 = 0,
    wProcessorLevel: u16 = 0,
    wProcessorRevision: u16 = 0,
};

//typedef struct _MEMORYSTATUSEX {
//   DWORD     dwLength;
//   DWORD     dwMemoryLoad;
//   DWORDLONG ullTotalPhys;
//   DWORDLONG ullAvailPhys;
//   DWORDLONG ullTotalPageFile;
//   DWORDLONG ullAvailPageFile;
//   DWORDLONG ullTotalVirtual;
//   DWORDLONG ullAvailVirtual;
//   DWORDLONG ullAvailExtendedVirtual;
// } MEMORYSTATUSEX, *LPMEMORYSTATUSEX;
pub const MEMORYSTATUSEX = extern struct {
    dwLength: u32 = @sizeOf(MEMORYSTATUSEX),
    dwMemoryLoad: u32 = 0,
    ullTotalPhys: u64 = 0,
    ullAvailPhys: u64 = 0,
    ullTatalPageFile: u64 = 0,
    ullAvailPageFile: u64 = 0,
    ullTatalVirtual: u64 = 0,
    ullAvailVirtual: u64 = 0,
    ullAvailExtendedVirtual: u64 = 0,
};

//typedef struct _COORD {
//   SHORT X;
//   SHORT Y;
// } COORD, *PCOORD;
pub const COORD = extern struct {
    X: i16,
    Y: i16,
};

//typedef struct _SMALL_RECT {
//   SHORT Left;
//   SHORT Top;
//   SHORT Right;
//   SHORT Bottom;
// } SMALL_RECT;
pub const SMALL_RECT = extern struct {
    Left: i16,
    Top: i16,
    Right: i16,
    Bottom: i16,
};

//typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
//   COORD      dwSize;
//   COORD      dwCursorPosition;
//   WORD       wAttributes;
//   SMALL_RECT srWindow;
//   COORD      dwMaximumWindowSize;
// } CONSOLE_SCREEN_BUFFER_INFO;
pub const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
    dwsize: COORD = .{ .X = 0, .Y = 0 },
    dwCursorPosition: COORD = .{ .X = 0, .Y = 0 },
    wAttributes: u16 = 0,
    srWindow: SMALL_RECT = .{ .Left = 0, .Top = 0, .Right = 0, .Bottom = 0 },
};

//typedef struct _OSVERSIONINFOW {
//   ULONG dwOSVersionInfoSize;
//   ULONG dwMajorVersion;
//   ULONG dwMinorVersion;
//   ULONG dwBuildNumber;
//   ULONG dwPlatformId;
//   WCHAR szCSDVersion[128];
// } OSVERSIONINFOW, *POSVERSIONINFOW, *LPOSVERSIONINFOW, RTL_OSVERSIONINFOW, *PRTL_OSVERSIONINFOW;
// windows version ...
pub const OSVERSIONINFOW = extern struct {
    dwOSVersionInfoSize: u32 = @sizeOf(OSVERSIONINFOW),
    dwMajorVersion: u32 = 0,
    dwMinorVersion: u32 = 0,
    dwBuildNumber: u32 = 0,
    dwPlatformId: u32 = 0,
    szCSDVersion: [128]u16 = [_]u16{0} ** 128,
};

// input handle
pub const KEY_EVENT_RECORD = extern struct {
    bKeyDown: u32 = 0,
    wRepeatCount: u16 = 0,
    wVirtualKeyCode: u16 = 0,
    wVirtualScanCode: u16 = 0,
    uChar: u16 = 0,
    dwControlKeyState: u32 = 0,
};

pub const INPUT_RECORD = extern struct {
    EventType: u16 = 0,
    _pad: u16 = 0,
    Event: KEY_EVENT_RECORD = .{},
};

//network

pub const SOCKET_ADDRESS = extern struct {
    lpSockaddr: ?*SOCKADDR = null,
    iSockaddrLength: i32 = 0,
    _pad: u32 = 0,
};

pub const SOCKADDR = extern struct {
    sa_family: u16 = 0,
    sa_data: [14]u8 = [_]u8{0} ** 14,
};

pub const IP_ADAPTER_ANYCAST_ADDRESS = extern struct {
    Length: u32 = 0,
    Flags: u32 = 0,
    Next: ?*IP_ADAPTER_ANYCAST_ADDRESS = null,
    Address: SOCKET_ADDRESS = .{},
};

pub const IP_ADAPTER_MULTICAST_ADDRESS = extern struct {
    Length: u32 = 0,
    Flags: u32 = 0,
    Next: ?*IP_ADAPTER_MULTICAST_ADDRESS = null,
    Address: SOCKET_ADDRESS = .{},
};

pub const IP_ADAPTER_DNS_SERVER_ADDRESS = extern struct {
    Length: u32 = 0,
    Reserved: u32 = 0,
    Next: ?*IP_ADAPTER_DNS_SERVER_ADDRESS = null,
    Address: SOCKET_ADDRESS = .{},
};

pub const IP_ADAPTER_PREFIX = extern struct {
    Length: u32 = 0,
    Flags: u32 = 0,
    Next: ?*IP_ADAPTER_PREFIX = null,
    Address: SOCKET_ADDRESS = .{},
    PrefixLength: u32 = 0,
};

//typedef struct _IP_ADAPTER_ADDRESSES_LH {
//   union {
//     ULONGLONG Alignment;
//     struct {
//       ULONG    Length;
//       IF_INDEX IfIndex;
//     };
//   };
//   struct _IP_ADAPTER_ADDRESSES_LH    *Next;
//   PCHAR                              AdapterName;
//   PIP_ADAPTER_UNICAST_ADDRESS_LH     FirstUnicastAddress;
//   PIP_ADAPTER_ANYCAST_ADDRESS_XP     FirstAnycastAddress;
//   PIP_ADAPTER_MULTICAST_ADDRESS_XP   FirstMulticastAddress;
//   PIP_ADAPTER_DNS_SERVER_ADDRESS_XP  FirstDnsServerAddress;
//   PWCHAR                             DnsSuffix;
//   PWCHAR                             Description;
//   PWCHAR                             FriendlyName;
//   BYTE                               PhysicalAddress[MAX_ADAPTER_ADDRESS_LENGTH];
//   ULONG                              PhysicalAddressLength;
//   union {
//     ULONG Flags;
//     struct {
//       ULONG DdnsEnabled : 1;
//       ULONG RegisterAdapterSuffix : 1;
//       ULONG Dhcpv4Enabled : 1;
//       ULONG ReceiveOnly : 1;
//       ULONG NoMulticast : 1;
//       ULONG Ipv6OtherStatefulConfig : 1;
//       ULONG NetbiosOverTcpipEnabled : 1;
//       ULONG Ipv4Enabled : 1;
//       ULONG Ipv6Enabled : 1;
//       ULONG Ipv6ManagedAddressConfigurationSupported : 1;
//     };
//   };
//   ULONG                              Mtu;
//   IFTYPE                             IfType;
//   IF_OPER_STATUS                     OperStatus;
//   IF_INDEX                           Ipv6IfIndex;
//   ULONG                              ZoneIndices[16];
//   PIP_ADAPTER_PREFIX_XP              FirstPrefix;
//   ULONG64                            TransmitLinkSpeed;
//   ULONG64                            ReceiveLinkSpeed;
//   PIP_ADAPTER_WINS_SERVER_ADDRESS_LH FirstWinsServerAddress;
//   PIP_ADAPTER_GATEWAY_ADDRESS_LH     FirstGatewayAddress;
//   ULONG                              Ipv4Metric;
//   ULONG                              Ipv6Metric;
//   IF_LUID                            Luid;
//   SOCKET_ADDRESS                     Dhcpv4Server;
//   NET_IF_COMPARTMENT_ID              CompartmentId;
//   NET_IF_NETWORK_GUID                NetworkGuid;
//   NET_IF_CONNECTION_TYPE             ConnectionType;
//   TUNNEL_TYPE                        TunnelType;
//   SOCKET_ADDRESS                     Dhcpv6Server;
//   BYTE                               Dhcpv6ClientDuid[MAX_DHCPV6_DUID_LENGTH];
//   ULONG                              Dhcpv6ClientDuidLength;
//   ULONG                              Dhcpv6Iaid;
//   PIP_ADAPTER_DNS_SUFFIX             FirstDnsSuffix;
// } IP_ADAPTER_ADDRESSES_LH, *PIP_ADAPTER_ADDRESSES_LH;
//
pub const IP_ADAPTER_ADDRESSES = extern struct {
    Length: u32 = 0,
    IfIndex: u32 = 0,
    Next: ?*IP_ADAPTER_ADDRESSES = null,
    AdapterName: [*:0]u8 = undefined,
    FirstUnicastAddress: ?*IP_ADAPTER_UNICAST_ADDRESS = null,
    FirstAnycastAddress: ?*IP_ADAPTER_ANYCAST_ADDRESS = null,
    FirstMulticastAddress: ?*IP_ADAPTER_MULTICAST_ADDRESS = null,
    FirstDnsServerAddress: ?*IP_ADAPTER_DNS_SERVER_ADDRESS = null,
    DnsSuffix: [*:0]u16 = undefined,
    Description: [*:0]u16 = undefined,
    FriendlyName: [*:0]u16 = undefined,
    PhysicalAddress: [8]u8 = [_]u8{0} ** 8,
    PhysicalAddressLength: u32 = 0,
    Flags: u32 = 0,
    Mtu: u32 = 0,
    IfType: u32 = 0,
    OperStatus: u32 = 0,
    Ipv6IfIndex: u32 = 0,
    ZoneIndices: [16]u32 = [_]u32{0} ** 16,
    FirstPrefix: ?*IP_ADAPTER_PREFIX = null,
    TransmitLinkSpeed: u64 = 0,
    ReceiveLinkSpeed: u64 = 0,
    FirstWinsServerAddress: ?*anyopaque = null,
    FirstGatewayAddress: ?*anyopaque = null,
    Ipv4Metric: u32 = 0,
    Ipv6Metric: u32 = 0,
    Luid: u64 = 0,
    Dhcpv4Server: SOCKET_ADDRESS = .{},
    CompartmentId: u32 = 0,
    NetworkGuid: [16]u8 = [_]u8{0} ** 16,
    ConnectionType: u32 = 0,
    TunnelType: u32 = 0,
    Dhcpv6Server: SOCKET_ADDRESS = .{},
    Dhcpv6ClientDuid: [130]u8 = [_]u8{0} ** 130,
    Dhcpv6ClientDuidLength: u32 = 0,
    Dhcpv6Iaid: u32 = 0,
    FirstDnsSuffix: ?*anyopaque = null,
};

//typedef struct _IP_ADAPTER_UNICAST_ADDRESS_LH {
//   union {
//     ULONGLONG Alignment;
//     struct {
//       ULONG Length;
//       DWORD Flags;
//     };
//   };
//   struct _IP_ADAPTER_UNICAST_ADDRESS_LH *Next;
//   SOCKET_ADDRESS                        Address;
//   IP_PREFIX_ORIGIN                      PrefixOrigin;
//   IP_SUFFIX_ORIGIN                      SuffixOrigin;
//   IP_DAD_STATE                          DadState;
//   ULONG                                 ValidLifetime;
//   ULONG                                 PreferredLifetime;
//   ULONG                                 LeaseLifetime;
//   UINT8                                 OnLinkPrefixLength;
// } IP_ADAPTER_UNICAST_ADDRESS_LH, *PIP_ADAPTER_UNICAST_ADDRESS_LH;

pub const IP_ADAPTER_UNICAST_ADDRESS = extern struct {
    Length: u32 = 0,
    Flags: u32 = 0,
    Next: ?*IP_ADAPTER_UNICAST_ADDRESS = null,
    Address: SOCKET_ADDRESS = .{},
    PrefixOrigin: u32 = 0,
    SuffixOrigin: u32 = 0,
    DadState: u32 = 0,
    ValidLifetime: u32 = 0,
    PreferredLifetime: u32 = 0,
    LeaseLifetime: u32 = 0,
    OnLinkPrefixLength: u8 = 0,
};

// MIB_IF_ROW2 - struct field layout is complex due to alignment padding,
// so we use a raw byte buffer and read fields at their known SDK offsets.
// Offsets verified from Windows SDK netioapi.h and windows-rs:
pub const MIB_IF_ROW2_SIZE = 1416;
pub const MIB_IF_ROW2_OFF_LUID = 0;
pub const MIB_IF_ROW2_OFF_INOCTETS = 1256;
pub const MIB_IF_ROW2_OFF_OUTOCTETS = 1320;

pub const MIB_IF_ROW2 = struct {
    buf: [MIB_IF_ROW2_SIZE]u8 = [_]u8{0} ** MIB_IF_ROW2_SIZE,

    pub fn setLuid(self: *MIB_IF_ROW2, luid: u64) void {
        std.mem.writeInt(u64, self.buf[MIB_IF_ROW2_OFF_LUID..][0..8], luid, .little);
    }
    pub fn getInOctets(self: *const MIB_IF_ROW2) u64 {
        return std.mem.readInt(u64, self.buf[MIB_IF_ROW2_OFF_INOCTETS..][0..8], .little);
    }
    pub fn getOutOctets(self: *const MIB_IF_ROW2) u64 {
        return std.mem.readInt(u64, self.buf[MIB_IF_ROW2_OFF_OUTOCTETS..][0..8], .little);
    }
};

pub const OSVersion = struct {
    major: u32,
    minor: u32,
    build: u32,
};
