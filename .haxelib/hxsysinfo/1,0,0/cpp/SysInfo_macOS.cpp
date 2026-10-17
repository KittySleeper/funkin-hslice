#include "SysInfo_macOS.h"
#if defined(__APPLE__)
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <vector>
#include <sstream>
#include <cstring>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <algorithm>
#include <sys/statvfs.h>
#include <mutex>
#include <chrono>
#include <sys/param.h>
#include <sys/mount.h>

namespace {
static ::String hx_stringg(const std::string &s){ return ::String::create(s.c_str()); }
static std::string sysctlString(const char *key){ size_t n=0; if(sysctlbyname(key,0,&n,0,0)!=0||!n) return ""; std::string s(n,'\0'); if(sysctlbyname(key,&s[0],&n,0,0)!=0) return ""; if(!s.empty()&&s[s.size()-1]=='\0') s.resize(s.size()-1); return s; }
static uint64_t sysctlU64(const char *key){ uint64_t v=0; size_t n=sizeof(v); return sysctlbyname(key,&v,&n,0,0)==0?v:0; }
static std::string cfString(CFTypeRef obj){ if(!obj||CFGetTypeID(obj)!=CFStringGetTypeID()) return ""; CFStringRef s=(CFStringRef)obj; char b[1024]; if(CFStringGetCString(s,b,sizeof(b),kCFStringEncodingUTF8)) return b; return ""; }
static std::vector<std::string> gpuNames(){ std::vector<std::string> out; io_iterator_t it=0; CFMutableDictionaryRef match=IOServiceMatching("IOAccelerator"); if(!match) return out; if(IOServiceGetMatchingServices(kIOMasterPortDefault,match,&it)!=KERN_SUCCESS) return out; io_object_t obj; while((obj=IOIteratorNext(it))){ CFMutableDictionaryRef props=0; if(IORegistryEntryCreateCFProperties(obj,&props,kCFAllocatorDefault,0)==KERN_SUCCESS&&props){ CFTypeRef model=CFDictionaryGetValue(props,CFSTR("model")); std::string n=cfString(model); if(n.empty()){ CFTypeRef name=CFDictionaryGetValue(props,CFSTR("IOName")); n=cfString(name); } if(!n.empty()) out.push_back(n); CFRelease(props); } IOObjectRelease(obj); } IOObjectRelease(it); return out; }

static std::string command(const std::string &cmd){ FILE *p=popen(cmd.c_str(),"r"); if(!p) return ""; char b[1024]; std::string out; while(fgets(b,sizeof(b),p)) out+=b; pclose(p); return out; }
static std::string trim(const std::string&s){ size_t a=s.find_first_not_of(" \t\r\n"); size_t b=s.find_last_not_of(" \t\r\n"); return a==std::string::npos?"":s.substr(a,b-a+1); }
static std::string infoField(const std::string &text,const std::string &key){ std::istringstream in(text); std::string line; while(std::getline(in,line)){ size_t p=line.find(':'); if(p!=std::string::npos && trim(line.substr(0,p))==key) return trim(line.substr(p+1)); } return ""; }
static bool realValue(const std::string &v){ return !v.empty() && v.rfind("Not applicable",0)!=0; }
static bool isRemovableValue(const std::string &v){ return v=="Removable" || v.find("Yes")!=std::string::npos; }
static std::string containerOf(const std::string &listLine){
    size_t p=listLine.find("Container disk");
    if(p==std::string::npos) return "";
    size_t start=p+10, end=start+4;
    while(end<listLine.size() && std::isdigit((unsigned char)listLine[end])) ++end;
    return end>start+4 ? listLine.substr(start,end-start) : "";
}
static uint64_t apfsContainerFree(const std::string &container){
    int n=getfsstat(0,0,MNT_NOWAIT);
    if(n<=0) return 0;
    std::vector<struct statfs> mounts(n);
    n=getfsstat(&mounts[0],(int)(mounts.size()*sizeof(struct statfs)),MNT_NOWAIT);
    std::string prefix="/dev/"+container+"s";
    for(int i=0;i<n;i++){
        if(std::strcmp(mounts[i].f_fstypename,"apfs")!=0) continue;
        if(std::strncmp(mounts[i].f_mntfromname,prefix.c_str(),prefix.size())!=0) continue;
        return (uint64_t)mounts[i].f_bavail*(uint64_t)mounts[i].f_bsize;
    }
    return 0;
}
struct PartitionInfo { std::string name; std::string fs; uint64_t size; uint64_t freeSpace; std::string container; };
struct DiskInfo { std::string name; std::string model; std::string type; uint64_t size; std::vector<PartitionInfo> partitions; };
static uint64_t parseBytes(const std::string &v){
    std::string s=trim(v);
    size_t bp=s.find(" Bytes)");
    if(bp!=std::string::npos){
        size_t lp=s.rfind('(',bp);
        if(lp!=std::string::npos){
            std::string n=s.substr(lp+1,bp-lp-1);
            n.erase(std::remove(n.begin(),n.end(),','),n.end());
            return (uint64_t)std::strtoull(n.c_str(),0,10);
        }
    }
    size_t lp2=s.rfind('(');
    if(lp2!=std::string::npos) s=s.substr(lp2+1);
    size_t bp2=s.find(" Bytes");
    if(bp2!=std::string::npos) s=trim(s.substr(0,bp2));
    std::string digits; for(char c:s) if(std::isdigit((unsigned char)c)) digits+=c;
    return digits.empty()?0:(uint64_t)std::strtoull(digits.c_str(),0,10);
}
static std::vector<DiskInfo> scanDisks(){
    std::vector<DiskInfo> out; std::string list=command("diskutil list physical 2>/dev/null"); std::istringstream in(list); std::string line; DiskInfo *cur=0;
    while(std::getline(in,line)){
        line=trim(line); if(line.empty()) continue;
        if(line.rfind("/dev/disk",0)==0 && line.find(":")!=std::string::npos){ size_t p=line.find(' '); std::string dev=p==std::string::npos?line.substr(0,line.find(':')):line.substr(0,p); DiskInfo d; d.name=dev; d.size=0; d.type="Unknown"; d.model=""; out.push_back(d); cur=&out.back();
            std::string inf=command("diskutil info "+dev+" 2>/dev/null"); cur->size=parseBytes(infoField(inf,"Disk Size")); cur->model=infoField(inf,"Device / Media Name"); if(cur->model.empty()) cur->model=infoField(inf,"Media Name"); if(isRemovableValue(infoField(inf,"Removable Media"))) cur->type="Removable"; else if(infoField(inf,"Solid State")=="Yes") cur->type="SSD"; else if(infoField(inf,"Solid State")=="No") cur->type="HDD";
            continue;
        }
        if(!cur) continue;
        if(line.size()>3 && std::isdigit((unsigned char)line[0]) && line.find(':')!=std::string::npos){ size_t colon=line.find(':'); std::string rest=trim(line.substr(colon+1)); size_t last=rest.find_last_of(' '); if(last==std::string::npos) continue; std::string dev=rest.substr(last+1); std::string base=cur->name.substr(cur->name.find_last_of('/')+1); if(dev.find(base)!=0 || dev==base) continue; std::string inf=command("diskutil info "+dev+" 2>/dev/null"); PartitionInfo pi; pi.container=containerOf(rest); pi.size=parseBytes(infoField(inf,"Disk Size")); pi.fs=infoField(inf,"File System Personality");
            pi.fs=infoField(inf,"File System Personality");if(pi.fs.empty() || pi.fs=="Not applicable (no file system)")pi.fs=infoField(inf,"Partition Type");
            if(pi.fs.empty() || pi.fs=="Not applicable (no file system)")pi.fs=infoField(inf,"Type (Bundle)");
            if(pi.fs=="Not applicable (no file system)")
                pi.fs=""; std::string mount=infoField(inf,"Mount Point"); std::string vol=infoField(inf,"Volume Name"); pi.name=realValue(mount)?mount:(realValue(vol)?vol:dev); pi.freeSpace=parseBytes(infoField(inf,"Volume Free Space")); cur->partitions.push_back(pi); }
    }
    for(size_t i=0;i<out.size();i++)
        for(size_t j=0;j<out[i].partitions.size();j++){
            PartitionInfo &p=out[i].partitions[j];
            if(p.freeSpace==0 && !p.container.empty()) p.freeSpace=apfsContainerFree(p.container);
        }
    return out;
}
static std::mutex g_disksMutex;
static std::vector<DiskInfo> g_disksCache;
static std::chrono::steady_clock::time_point g_disksStamp;
static bool g_disksValid=false;
static std::vector<DiskInfo> disks(bool forceRefresh=false){
    std::lock_guard<std::mutex> lock(g_disksMutex);
    if(forceRefresh || !g_disksValid || std::chrono::steady_clock::now()-g_disksStamp>std::chrono::seconds(10)){
        g_disksCache=scanDisks();
        g_disksStamp=std::chrono::steady_clock::now();
        g_disksValid=true;
    }
    return g_disksCache;
}
static double availableRAM(){ mach_msg_type_number_t count=HOST_VM_INFO64_COUNT; vm_statistics64_data_t vm; if(host_statistics64(mach_host_self(),HOST_VM_INFO64,(host_info64_t)&vm,&count)!=KERN_SUCCESS) return 0; return (double)(vm.free_count+vm.inactive_count)*vm_kernel_page_size; }
static bool isRosettaTranslated(){
    int ret=0; size_t size=sizeof(ret);
    if(sysctlbyname("sysctl.proc_translated",&ret,&size,0,0)==-1) return false;
    return ret==1;
}
static int currentPowerState(io_object_t obj){
    CFMutableDictionaryRef props=0; int state=-1;
    if(IORegistryEntryCreateCFProperties(obj,&props,kCFAllocatorDefault,0)==KERN_SUCCESS && props){
        CFTypeRef pm=CFDictionaryGetValue(props,CFSTR("IOPowerManagement"));
        if(pm && CFGetTypeID(pm)==CFDictionaryGetTypeID()){
            CFTypeRef cur=CFDictionaryGetValue((CFDictionaryRef)pm,CFSTR("CurrentPowerState"));
            if(cur && CFGetTypeID(cur)==CFNumberGetTypeID()){
                int v=0; if(CFNumberGetValue((CFNumberRef)cur,kCFNumberIntType,&v)) state=v;
            }
        }
        CFRelease(props);
    }
    return state;
}
}
namespace SysInfo {
::String getOS(){ return HX_CSTRING("macOS"); }
::String getOSVersion(){ return hx_stringg(sysctlString("kern.osproductversion")); }
::String getArchitecture(){ if(isRosettaTranslated()) return HX_CSTRING("arm64"); struct utsname u; return uname(&u)==0?hx_stringg(u.machine):HX_CSTRING(""); }
::String getCPUName(){ return hx_stringg(trim(sysctlString("machdep.cpu.brand_string"))); }
int getCPUCoreCount(){ return (int)sysctlU64("hw.physicalcpu"); }
int getCPUThreadCount(){ return (int)sysctlU64("hw.logicalcpu"); }
double getTotalRAM(){ return (double)sysctlU64("hw.memsize"); }
double getAvailableRAM(){ return availableRAM(); }
int getGPUCount(){ return (int)gpuNames().size(); }
::String getGPUName(int i){ std::vector<std::string> g=gpuNames(); return i>=0&&i<(int)g.size()?hx_stringg(g[i]):HX_CSTRING(""); }
double getGPUVRAM(int i){ (void)i; return 0; }
::String getManufacturer(){ return HX_CSTRING("Apple"); }
::String getModel(){ return hx_stringg(sysctlString("hw.model")); }
::String getHostname(){ char b[256]; size_t n=sizeof(b); return gethostname(b,sizeof(b))==0?hx_stringg(std::string(b)):HX_CSTRING(""); }
double getUptime(){ struct timeval tv; size_t n=sizeof(tv); if(sysctlbyname("kern.boottime",&tv,&n,0,0)!=0) return 0; time_t now=time(0); return difftime(now,tv.tv_sec); }
int getDiskCount(){ return (int)disks(true).size(); }
::String getDiskName(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].name):HX_CSTRING(""); }
::String getDiskModel(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].model):HX_CSTRING(""); }
::String getDiskType(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].type):HX_CSTRING("Unknown"); }
double getDiskSize(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?(double)d[i].size:0; }
int getPartitionCount(int di){ std::vector<DiskInfo>d=disks(); return di>=0&&di<(int)d.size()?(int)d[di].partitions.size():0; }
::String getPartitionName(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return HX_CSTRING(""); return hx_stringg(d[di].partitions[pi].name); }
::String getPartitionFileSystem(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return HX_CSTRING(""); return hx_stringg(d[di].partitions[pi].fs); }
double getPartitionSize(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return 0; return (double)d[di].partitions[pi].size; }
double getPartitionFreeSpace(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return 0; return (double)d[di].partitions[pi].freeSpace; }
int getSystemDiskIndex(){
    std::string whole=infoField(command("diskutil info / 2>/dev/null"),"Part of Whole");
    if(whole.empty()) return -1;
    std::string physStore=infoField(command("diskutil info "+whole+" 2>/dev/null"),"APFS Physical Store");
    std::string diskId=whole;
    if(!physStore.empty()){
        size_t sPos=physStore.find('s',4);
        diskId=sPos==std::string::npos?physStore:physStore.substr(0,sPos);
    }
    std::vector<DiskInfo>d=disks();
    for(size_t i=0;i<d.size();i++){ std::string base=d[i].name.substr(d[i].name.find_last_of('/')+1); if(base==diskId) return (int)i; }
    return -1;
}
}
#endif