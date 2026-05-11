const std = @import("std");
const windows = std.os.windows;
pub const types = @import("types.zig");

//ULONGLONG GetTickCount64();
pub extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;

//BOOL GetSystemTimes(
//   [out, optional] PFILETIME lpIdleTime,
//   [out, optional] PFILETIME lpKernelTime,
//   [out, optional] PFILETIME lpUserTime
// );
pub extern "kernel32" fn GetSystemTimes(*types.FILETIME, *types.FILETIME, *types.FILETIME) callconv(.winapi) windows.BOOL;

//VOID GetSystemInfo(
//   [out] LPSYSTEM_INFO lpSystemInfo
// );
pub extern "kernel32" fn GetSystemInfo(*types.SYSTEM_INFO) callconv(.winapi) void;

//BOOL GetComputerNameExA(
//   [in]      COMPUTER_NAME_FORMAT NameType,
//   [out]     LPSTR                lpBuffer,
//   [in, out] LPDWORD              nSize
// );
pub extern "kernel32" fn GetComputerNameExA(u32, [*]u8, *u32) callconv(.winapi) windows.BOOL;

// BOOL GlobalMemoryStatusEx(
//   [in, out] LPMEMORYSTATUSEX lpBuffer
// );
pub extern "kernel32" fn GlobalMemoryStatusEx(*types.MEMORYSTATUSEX) callconv(.winapi) windows.BOOL;

//DWORD GetLogicalDriveStringsA(
//   [in]  DWORD nBufferLength,
//   [out] LPSTR lpBuffer
// );
pub extern "kernel32" fn GetLogicalDriveStringsA(u32, [*]u8) callconv(.winapi) u32;

//BOOL GetDiskFreeSpaceExA(
//   [in, optional]  LPCSTR          lpDirectoryName,
//   [out, optional] PULARGE_INTEGER lpFreeBytesAvailableToCaller,
//   [out, optional] PULARGE_INTEGER lpTotalNumberOfBytes,
//   [out, optional] PULARGE_INTEGER lpTotalNumberOfFreeBytes
// );
pub extern "kernel32" fn GetDiskFreeSpaceExA([*:0]const u8, *u64, *u64, *u64) callconv(.winapi) windows.BOOL;

//HANDLE WINAPI GetStdHandle(
//   _In_ DWORD nStdHandle
// );
pub extern "kernel32" fn GetStdHandle(u32) callconv(.winapi) ?windows.HANDLE;

//BOOL WINAPI GetConsoleMode(
//   _In_  HANDLE  hConsoleHandle,
//   _Out_ LPDWORD lpMode
// );
pub extern "kernel32" fn GetConsoleMode(windows.HANDLE, *u32) callconv(.winapi) windows.BOOL;

//BOOL WINAPI SetConsoleMode(
//   _In_ HANDLE hConsoleHandle,
//   _In_ DWORD  dwMode
// );
pub extern "kernel32" fn SetConsoleMode(windows.HANDLE, u32) callconv(.winapi) windows.BOOL;

//BOOL WINAPI SetConsoleCursorPosition(
//  _In_ HANDLE hConsoleOutput,
//  _In_ COORD  dwCursorPosition
//);
pub extern "kernel32" fn SetConsoleCursorPosition(windows.HANDLE, types.COORD) callconv(.winapi) windows.BOOL;

//BOOL WINAPI SetConsoleOutputCP(
//  _In_ UINT wCodePageID
//);
pub extern "kernel32" fn SetConsoleOutputCP(u32) callconv(.winapi) windows.BOOL;

//BOOL GetComputerNameExW(
//  [in]      COMPUTER_NAME_FORMAT NameType,
//  [out]     LPWSTR               lpBuffer,
//  [in, out] LPDWORD              nSize
//);
pub extern "kernel32" fn GetComputerNameExW(u32, ?[*]u16, *u32) callconv(.winapi) windows.BOOL;

//NTSYSAPI NTSTATUS RtlGetVersion(
//  [out] PRTL_OSVERSIONINFOW lpVersionInformation
//);
pub extern "ntdll" fn RtlGetVersion(*types.OSVERSIONINFOW) callconv(.winapi) u32;

//BOOL WINAPI GetNumberOfConsoleInputEvents(
//  _In_  HANDLE  hConsoleInput,
//  _Out_ LPDWORD lpcNumberOfEvents
//);
pub extern "kernel32" fn GetNumberOfConsoleInputEvents(windows.HANDLE, *u32) callconv(.winapi) windows.BOOL;

//BOOL WINAPI ReadConsoleInput(
//  _In_  HANDLE        hConsoleInput,
//  _Out_ PINPUT_RECORD lpBuffer,
//  _In_  DWORD         nLength,
//  _Out_ LPDWORD       lpNumberOfEventsRead
//);
pub extern "kernel32" fn ReadConsoleInputA(windows.HANDLE, *types.INPUT_RECORD, u32, *u32) callconv(.winapi) windows.BOOL;

// network
//IPHLPAPI_DLL_LINKAGE ULONG GetAdaptersAddresses(
//  [in]      ULONG                 Family,
//  [in]      ULONG                 Flags,
//  [in]      PVOID                 Reserved,
//  [in, out] PIP_ADAPTER_ADDRESSES AdapterAddresses,
//  [in, out] PULONG                SizePointer
//);
pub extern "iphlpapi" fn GetAdaptersAddresses(u32, u32, ?*anyopaque, ?*types.IP_ADAPTER_ADDRESSES, *u32) callconv(.winapi) u32;

//PCSTR WSAAPI inet_ntop(
//  [in]  INT        Family,
//  [in]  const VOID *pAddr,
//  [out] PSTR       pStringBuf,
//  [in]  size_t     StringBufSize
//);
pub extern "ws2_32" fn inet_ntop(i32, *const anyopaque, [*]u8, u32) callconv(.winapi) ?[*:0]u8;

//IPHLPAPI_DLL_LINKAGE _NETIOAPI_SUCCESS_ NETIOAPI_API GetIfEntry2(
//  PMIB_IF_ROW2 Row
//);
pub extern "iphlpapi" fn GetIfEntry2(*anyopaque) callconv(.winapi) u32;
