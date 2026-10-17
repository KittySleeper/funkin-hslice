#include "SysInfo_Windows.h"
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <dxgi1_6.h>
#include <intrin.h>
#include <string>
#include <vector>
#include <sstream>
#include <algorithm>
#include <thread>
#include <stdint.h>
#include <winioctl.h>
#pragma comment(lib, "dxgi.lib")

namespace {
static ::String hx_stringg(const std::string &s) { return ::String::create(s.c_str()); }
static std::string trim(const std::string &s) { size_t a=s.find_first_not_of(" \t\r\n"); size_t b=s.find_last_not_of(" \t\r\n"); return a==std::string::npos?"":s.substr(a,b-a+1); }
static std::string regString(HKEY root, const char *path, const char *value) {
    HKEY key = 0; std::string out;
    if (RegOpenKeyExA(root, path, 0, KEY_READ, &key) != ERROR_SUCCESS) return out;
    char buf[512]; DWORD type = 0, size = sizeof(buf);
    if (RegQueryValueExA(key, value, 0, &type, (LPBYTE)buf, &size) == ERROR_SUCCESS && (type == REG_SZ || type == REG_EXPAND_SZ))
        out.assign(buf, size && buf[size-1] == 0 ? size-1 : size);
    RegCloseKey(key); return out;
}
static std::string nativeArch() {
    SYSTEM_INFO si; GetNativeSystemInfo(&si);
    switch (si.wProcessorArchitecture) {
        case PROCESSOR_ARCHITECTURE_AMD64: return "x86_64";
        case PROCESSOR_ARCHITECTURE_ARM64: return "ARM64";
        case PROCESSOR_ARCHITECTURE_INTEL: return "x86";
        case PROCESSOR_ARCHITECTURE_ARM: return "ARM";
        default: return "Unknown";
    }
}
static std::string windowsVersion() {
    typedef LONG (WINAPI *RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    if (!ntdll) return "";
    RtlGetVersionPtr fn = (RtlGetVersionPtr)GetProcAddress(ntdll, "RtlGetVersion");
    if (!fn) return "";
    RTL_OSVERSIONINFOW vi; ZeroMemory(&vi, sizeof(vi)); vi.dwOSVersionInfoSize = sizeof(vi);
    if (fn(&vi) != 0) return "";
    std::ostringstream ss; ss << vi.dwMajorVersion << "." << vi.dwMinorVersion << "." << vi.dwBuildNumber;
    return ss.str();
}
static std::vector<DXGI_ADAPTER_DESC1> adapters() {
    std::vector<DXGI_ADAPTER_DESC1> out;
    IDXGIFactory1 *factory = 0;
    if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory))) return out;
    for (UINT i=0;;++i) {
        IDXGIAdapter1 *a = 0;
        if (factory->EnumAdapters1(i, &a) == DXGI_ERROR_NOT_FOUND) break;
        DXGI_ADAPTER_DESC1 d; if (SUCCEEDED(a->GetDesc1(&d)) && !(d.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)) out.push_back(d);
        a->Release();
    }
    factory->Release(); return out;
}
static std::string wideToUtf8(const wchar_t *w) {
    if (!w) return ""; int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, 0, 0, 0, 0); if (n <= 1) return "";
    std::string s(n-1, '\0'); WideCharToMultiByte(CP_UTF8, 0, w, -1, &s[0], n, 0, 0); return s;
}

struct PartitionInfo {
    DWORD diskNumber;
    ULONGLONG offset;
    ULONGLONG size;
    std::string name;
    std::string fs;
    ULONGLONG freeSpace;
};
struct DiskInfo {
    int number;
    std::string name;
    std::string model;
    std::string type;
    ULONGLONG size;
    std::vector<PartitionInfo> partitions;
};
static std::string physicalPath(int n){ std::ostringstream s; s<<"\\\\.\\PhysicalDrive"<<n; return s.str(); }
static std::string volumeLabel(const std::string &volume){
    char name[MAX_PATH]={0}, fs[MAX_PATH]={0}; DWORD serial=0,maxlen=0,flags=0;
    if(GetVolumeInformationA(volume.c_str(),name,MAX_PATH,&serial,&maxlen,&flags,fs,MAX_PATH)) return name;
    return "";
}
static std::string volumeFs(const std::string &volume){
    char fs[MAX_PATH]={0}; if(GetVolumeInformationA(volume.c_str(),0,0,0,0,0,fs,MAX_PATH)) return fs; return "";
}
static ULONGLONG volumeFree(const std::string &volume){
    ULARGE_INTEGER freeBytes={0},total={0},freeTotal={0};
    return GetDiskFreeSpaceExA(volume.c_str(),&freeBytes,&total,&freeTotal)?freeBytes.QuadPart:0;
}
static std::vector<PartitionInfo> volumePartitions(){
    std::vector<PartitionInfo> out;
    DWORD mask=GetLogicalDrives();
    if(!mask) return out;
    for(int letter=0;letter<26;letter++){
        if(!(mask&(1u<<letter))) continue;
        char root[4]={(char)('A'+letter),':','\\','\0'};
        std::string volume=root;
        HANDLE vh=CreateFileA((std::string("\\\\.\\")+root[0]+":").c_str(),0,FILE_SHARE_READ|FILE_SHARE_WRITE,0,OPEN_EXISTING,0,0);
        if(vh==INVALID_HANDLE_VALUE) continue;
        VOLUME_DISK_EXTENTS ex; DWORD bytes=0; ZeroMemory(&ex,sizeof(ex));
        if(DeviceIoControl(vh,IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,0,0,&ex,sizeof(ex),&bytes,0)){
            char label[MAX_PATH]={0}, fs[MAX_PATH]={0}; DWORD serial=0,maxlen=0,flags=0;
            GetVolumeInformationA(root,label,MAX_PATH,&serial,&maxlen,&flags,fs,MAX_PATH);
            ULARGE_INTEGER freeBytes={0},total={0},freeTotal={0};
            GetDiskFreeSpaceExA(root,&freeBytes,&total,&freeTotal);
            for(DWORD i=0;i<ex.NumberOfDiskExtents;i++){
                PartitionInfo x;
                x.diskNumber=ex.Extents[i].DiskNumber;
                x.offset=ex.Extents[i].StartingOffset.QuadPart;
                x.size=ex.Extents[i].ExtentLength.QuadPart;
                x.name=root;
                if(label[0]) x.name=std::string(root)+" ("+label+")";
                x.fs=fs;
                x.freeSpace=freeBytes.QuadPart;
                out.push_back(x);
            }
        }
        CloseHandle(vh);
    }
    return out;
}

static std::string storageModel(HANDLE h){
    STORAGE_PROPERTY_QUERY q; ZeroMemory(&q,sizeof(q)); q.PropertyId=StorageDeviceProperty; q.QueryType=PropertyStandardQuery;
    BYTE buf[4096]; DWORD bytes=0; if(!DeviceIoControl(h,IOCTL_STORAGE_QUERY_PROPERTY,&q,sizeof(q),buf,sizeof(buf),&bytes,0)) return "";
    STORAGE_DEVICE_DESCRIPTOR *d=(STORAGE_DEVICE_DESCRIPTOR*)buf; if(d->ProductIdOffset && d->ProductIdOffset<bytes) return trim(std::string((char*)buf+d->ProductIdOffset));
    return "";
}
static std::vector<DiskInfo> disks(){
    std::vector<DiskInfo> out; std::vector<PartitionInfo> vp=volumePartitions();
    for(int n=0;n<64;n++){
        HANDLE h=CreateFileA(physicalPath(n).c_str(),0,FILE_SHARE_READ|FILE_SHARE_WRITE,0,OPEN_EXISTING,0,0); if(h==INVALID_HANDLE_VALUE) continue;
        DISK_GEOMETRY_EX geo; DWORD bytes=0; ULONGLONG size=0; if(DeviceIoControl(h,IOCTL_DISK_GET_DRIVE_GEOMETRY_EX,0,0,&geo,sizeof(geo),&bytes,0)) size=geo.DiskSize.QuadPart;
        STORAGE_HOTPLUG_INFO hot; ZeroMemory(&hot,sizeof(hot)); bool removable=false; if(DeviceIoControl(h,IOCTL_STORAGE_GET_HOTPLUG_INFO,0,0,&hot,sizeof(hot),&bytes,0)) removable=hot.MediaRemovable||hot.DeviceHotplug;
        std::string model=storageModel(h); std::string type="Unknown";
        STORAGE_DEVICE_DESCRIPTOR d; ZeroMemory(&d,sizeof(d)); STORAGE_PROPERTY_QUERY q; ZeroMemory(&q,sizeof(q)); q.PropertyId=StorageDeviceProperty; q.QueryType=PropertyStandardQuery;
        BYTE buf[4096]; if(DeviceIoControl(h,IOCTL_STORAGE_QUERY_PROPERTY,&q,sizeof(q),buf,sizeof(buf),&bytes,0)){ STORAGE_DEVICE_DESCRIPTOR *sd=(STORAGE_DEVICE_DESCRIPTOR*)buf; if(sd->RemovableMedia) removable=true; if(sd->BusType==BusTypeUsb||sd->BusType==BusTypeSd||sd->BusType==BusTypeMmc) removable=true; }
        if(removable) type="Removable";
        else { STORAGE_PROPERTY_QUERY aq; ZeroMemory(&aq,sizeof(aq)); aq.PropertyId=StorageDeviceSeekPenaltyProperty; aq.QueryType=PropertyStandardQuery; DEVICE_SEEK_PENALTY_DESCRIPTOR sp; ZeroMemory(&sp,sizeof(sp)); if(DeviceIoControl(h,IOCTL_STORAGE_QUERY_PROPERTY,&aq,sizeof(aq),&sp,sizeof(sp),&bytes,0)) type=sp.IncursSeekPenalty?"HDD":"SSD"; }
        DiskInfo di; di.number=n; di.name="PhysicalDrive"+std::to_string(n); di.model=model; di.type=type; di.size=size;
        BYTE layoutBuf[16384]; if(DeviceIoControl(h,IOCTL_DISK_GET_DRIVE_LAYOUT_EX,0,0,layoutBuf,sizeof(layoutBuf),&bytes,0)){
            DRIVE_LAYOUT_INFORMATION_EX *layout=(DRIVE_LAYOUT_INFORMATION_EX*)layoutBuf;
            for(DWORD i=0;i<layout->PartitionCount;i++){ PARTITION_INFORMATION_EX &p=layout->PartitionEntry[i]; if(p.PartitionLength.QuadPart==0) continue; PartitionInfo pi; pi.diskNumber=n; pi.offset=p.StartingOffset.QuadPart; pi.size=p.PartitionLength.QuadPart; pi.freeSpace=0; for(size_t j=0;j<vp.size();j++) if(vp[j].diskNumber==(DWORD)n && vp[j].offset==pi.offset){ pi.name=vp[j].name; pi.fs=vp[j].fs; pi.freeSpace=vp[j].freeSpace; break; } if(pi.name.empty()){ std::ostringstream x; x<<"PhysicalDrive"<<n<<" Partition"<<(i+1); pi.name=x.str(); } di.partitions.push_back(pi); }
        }
        CloseHandle(h); out.push_back(di);
    }
    return out;
}
static int systemDiskNumber(){
    char winDir[MAX_PATH];
    if(!GetWindowsDirectoryA(winDir,MAX_PATH) || !winDir[0]) return -1;
    std::string volume=std::string("\\\\.\\")+winDir[0]+":";
    HANDLE vh=CreateFileA(volume.c_str(),0,FILE_SHARE_READ|FILE_SHARE_WRITE,0,OPEN_EXISTING,0,0);
    if(vh==INVALID_HANDLE_VALUE) return -1;
    VOLUME_DISK_EXTENTS ex; DWORD bytes=0; ZeroMemory(&ex,sizeof(ex));
    int diskNumber=-1;
    if(DeviceIoControl(vh,IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,0,0,&ex,sizeof(ex),&bytes,0) && ex.NumberOfDiskExtents>0)
        diskNumber=(int)ex.Extents[0].DiskNumber;
    CloseHandle(vh);
    return diskNumber;
}
static int physicalCores() {
    DWORD len = 0; GetLogicalProcessorInformationEx(RelationProcessorCore, 0, &len);
    if (!len) return (int)std::thread::hardware_concurrency();
    std::vector<unsigned char> buf(len);
    if (!GetLogicalProcessorInformationEx(RelationProcessorCore, (PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX)&buf[0], &len)) return 0;
    int count = 0; for (DWORD off=0; off<len;) { PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX p=(PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX)(&buf[off]); ++count; off += p->Size; } return count;
}
}
namespace SysInfo {
::String getOS(){ return HX_CSTRING("Windows"); }
::String getOSVersion(){ return hx_stringg(windowsVersion()); }
::String getArchitecture(){ return hx_stringg(nativeArch()); }
::String getCPUName(){ return hx_stringg(regString(HKEY_LOCAL_MACHINE,"HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0","ProcessorNameString")); }
int getCPUCoreCount(){ int n=physicalCores(); return n>0?n:(int)GetActiveProcessorCount(ALL_PROCESSOR_GROUPS); }
int getCPUThreadCount(){ return (int)GetActiveProcessorCount(ALL_PROCESSOR_GROUPS); }
double getTotalRAM(){ MEMORYSTATUSEX m; m.dwLength=sizeof(m); return GlobalMemoryStatusEx(&m)?(double)m.ullTotalPhys:0; }
double getAvailableRAM(){ MEMORYSTATUSEX m; m.dwLength=sizeof(m); return GlobalMemoryStatusEx(&m)?(double)m.ullAvailPhys:0; }
int getGPUCount(){ return (int)adapters().size(); }
::String getGPUName(int index){ std::vector<DXGI_ADAPTER_DESC1> a=adapters(); if(index<0||index>=(int)a.size()) return HX_CSTRING(""); return hx_stringg(wideToUtf8(a[index].Description)); }
double getGPUVRAM(int index){ std::vector<DXGI_ADAPTER_DESC1> a=adapters(); if(index<0||index>=(int)a.size()) return 0; return (double)a[index].DedicatedVideoMemory; }
::String getManufacturer(){ return hx_stringg(regString(HKEY_LOCAL_MACHINE,"HARDWARE\\DESCRIPTION\\System\\BIOS","SystemManufacturer")); }
::String getModel(){ return hx_stringg(regString(HKEY_LOCAL_MACHINE,"HARDWARE\\DESCRIPTION\\System\\BIOS","SystemProductName")); }
::String getHostname(){ char b[256]; DWORD n=sizeof(b); return GetComputerNameA(b,&n)?hx_stringg(std::string(b,n)):HX_CSTRING(""); }
double getUptime(){ return (double)GetTickCount64()/1000.0; }
int getDiskCount(){ return (int)disks().size(); }
::String getDiskName(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].name):HX_CSTRING(""); }
::String getDiskModel(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].model):HX_CSTRING(""); }
::String getDiskType(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].type):HX_CSTRING("Unknown"); }
double getDiskSize(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?(double)d[i].size:0; }
int getPartitionCount(int di){ std::vector<DiskInfo>d=disks(); return di>=0&&di<(int)d.size()?(int)d[di].partitions.size():0; }
::String getPartitionName(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return HX_CSTRING(""); return hx_stringg(d[di].partitions[pi].name); }
::String getPartitionFileSystem(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return HX_CSTRING(""); return hx_stringg(d[di].partitions[pi].fs); }
double getPartitionSize(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return 0; return (double)d[di].partitions[pi].size; }
double getPartitionFreeSpace(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return 0; return (double)d[di].partitions[pi].freeSpace; }
int getSystemDiskIndex(){ int num=systemDiskNumber(); if(num<0) return -1; std::vector<DiskInfo>d=disks(); for(size_t i=0;i<d.size();i++) if(d[i].number==num) return (int)i; return -1; }
}
#endif