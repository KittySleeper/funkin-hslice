#include "SysInfo_Linux.h"
#if defined(__linux__) && !defined(__ANDROID__)
#include <sys/sysinfo.h>
#include <sys/utsname.h>
#include <sys/personality.h>
#include <unistd.h>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <dirent.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <algorithm>
#include <utility>
#include <sys/statvfs.h>
#include <mntent.h>

namespace {
static ::String hx_stringg(const std::string &s){ return ::String::create(s.c_str()); }
static std::string readFile(const std::string &p){ std::ifstream f(p.c_str()); if(!f) return ""; std::ostringstream s; s<<f.rdbuf(); return s.str(); }
static std::string trim(const std::string &s){ size_t a=s.find_first_not_of(" \t\r\n"); size_t b=s.find_last_not_of(" \t\r\n"); return a==std::string::npos?"":s.substr(a,b-a+1); }
static std::string field(const std::string &text,const std::string &key){ std::istringstream in(text); std::string l; while(std::getline(in,l)){ if(l.compare(0,key.size(),key)==0){ size_t p=l.find(':'); if(p!=std::string::npos) return trim(l.substr(p+1)); } } return ""; }
static std::string cpuName(){ std::string s=readFile("/proc/cpuinfo"); std::string x=field(s,"model name"); if(x.empty()) x=field(s,"Hardware"); return x; }
static std::string architecture(){
    struct utsname u;
    if(uname(&u)!=0) return "";
    std::string mach=u.machine;
    int orig=personality(0xffffffff);
    if(orig!=-1 && (orig & PER_MASK)==PER_LINUX32){
        if(personality(PER_LINUX)!=-1){
            struct utsname u2;
            if(uname(&u2)==0) mach=u2.machine;
            personality(orig);
        }
    }
    return mach;
}
static int physicalCoreCount(){
    std::string s=readFile("/proc/cpuinfo");
    std::istringstream in(s);
    std::string line, curPhys, curCore;
    bool haveCoreId=false;
    std::vector<std::pair<std::string,std::string>> seen;
    auto flush=[&](){
        if(haveCoreId){
            std::pair<std::string,std::string> key(curPhys,curCore);
            if(std::find(seen.begin(),seen.end(),key)==seen.end()) seen.push_back(key);
        }
        curPhys.clear(); curCore.clear(); haveCoreId=false;
    };
    while(std::getline(in,line)){
        if(line.compare(0,11,"physical id")==0){
            size_t p=line.find(':'); if(p!=std::string::npos) curPhys=trim(line.substr(p+1));
        } else if(line.compare(0,7,"core id")==0){
            size_t p=line.find(':'); if(p!=std::string::npos){ curCore=trim(line.substr(p+1)); haveCoreId=true; }
        } else if(line.empty()){
            flush();
        }
    }
    flush();
    return (int)seen.size();
}
static std::string osVersion(){ std::string s=readFile("/etc/os-release"); std::istringstream in(s); std::string l; while(std::getline(in,l)){ if(l.compare(0,11,"PRETTY_NAME")==0){ size_t p=l.find('='); if(p!=std::string::npos){ std::string v=l.substr(p+1); if(v.size()>1 && v[0]=='"' && v[v.size()-1]=='"') v=v.substr(1,v.size()-2); return v; } } } return "Linux"; }
static std::string command(const char *cmd){ FILE *p=popen(cmd,"r"); if(!p) return ""; char b[512]; std::string out; while(fgets(b,sizeof(b),p)) out+=b; pclose(p); return trim(out); }
static std::vector<std::string> splitQuotedFields(const std::string &line){
    std::vector<std::string> out;
    size_t pos = 0;
    while (true) {
        size_t a = line.find('"', pos);
        if (a == std::string::npos) break;
        size_t b = line.find('"', a + 1);
        if (b == std::string::npos) break;
        out.push_back(line.substr(a + 1, b - a - 1));
        pos = b + 1;
    }
    return out;
}
static std::string stripTrailingPciId(const std::string &s){
    if (s.empty() || s.back() != ']') return s;
    size_t open = s.rfind('[');
    if (open == std::string::npos) return s;
    std::string inner = s.substr(open + 1, s.size() - open - 2);
    if (inner.empty() || inner.size() > 4) return s;
    for (char c : inner) if (!std::isxdigit((unsigned char)c)) return s;
    return trim(s.substr(0, open));
}
struct GpuInfo {
    std::string slot;
    std::string name;
};
static std::vector<GpuInfo> gpus(){
    std::vector<GpuInfo> out;
    std::string l=command("lspci -D -mm -nn 2>/dev/null");
    std::istringstream in(l); std::string line;
    while(std::getline(in,line)){
        if(line.find("VGA compatible controller")==std::string::npos && line.find("3D controller")==std::string::npos && line.find("Display controller")==std::string::npos) continue;
        std::vector<std::string> fields = splitQuotedFields(line);
        size_t sp=line.find(' ');
        if(fields.size()<3 || sp==std::string::npos) continue;
        GpuInfo g;
        g.slot=line.substr(0,sp);
        g.name=trim(stripTrailingPciId(fields[1]) + " " + stripTrailingPciId(fields[2]));
        if(g.name.empty()) continue;
        out.push_back(g);
    }
    return out;
}
static std::string lower(std::string s){ std::transform(s.begin(),s.end(),s.begin(),[](unsigned char c){ return (char)std::tolower(c); }); return s; }
static std::string pciAddrOf(const std::string &devicePath){
    char buf[512];
    ssize_t n=readlink(devicePath.c_str(),buf,sizeof(buf)-1);
    if(n<=0) return "";
    buf[n]=0;
    std::string target=buf;
    size_t slash=target.find_last_of('/');
    return lower(slash==std::string::npos?target:target.substr(slash+1));
}
static std::string pciSlotOf(const std::string &drmDevicePath){
    char buf[512];
    ssize_t n=readlink(drmDevicePath.c_str(),buf,sizeof(buf)-1);
    if(n<=0) return "";
    buf[n]=0;
    std::string target=buf;
    size_t slash=target.find_last_of('/');
    std::string base=slash==std::string::npos?target:target.substr(slash+1);
    size_t colon=base.find(':');
    return colon==std::string::npos?base:base.substr(colon+1);
}
static int bootVgaIndex(const std::vector<std::string> &slots){
    DIR *d=opendir("/sys/class/drm"); if(!d) return -1;
    struct dirent *e; int result=-1;
    while((e=readdir(d))){
        std::string n=e->d_name;
        if(n.size()<5 || n.compare(0,4,"card")!=0 || n.find('-')!=std::string::npos) continue;
        std::string flag=trim(readFile(std::string("/sys/class/drm/")+n+"/device/boot_vga"));
        if(flag=="1"){
            std::string slot=pciSlotOf(std::string("/sys/class/drm/")+n+"/device");
            for(size_t i=0;i<slots.size();++i) if(slots[i]==slot){ result=(int)i; break; }
            break;
        }
    }
    closedir(d);
    return result;
}

struct DiskInfo {
    std::string name;
    std::string model;
    std::string type;
    uint64_t size;
    std::vector<std::string> partitions;
};
static bool exists(const std::string &p){ return access(p.c_str(), F_OK)==0; }
static std::string firstLine(const std::string &p){ return trim(readFile(p)); }
static std::vector<DiskInfo> disks(){
    std::vector<DiskInfo> out;
    DIR *d=opendir("/sys/block"); if(!d) return out;
    struct dirent *e;
    while((e=readdir(d))){
        std::string n=e->d_name;
        if(n=="."||n==".."||n.rfind("loop",0)==0||n.rfind("ram",0)==0||n.rfind("zram",0)==0||n.rfind("fd",0)==0) continue;
        std::string base="/sys/block/"+n;
        if(!exists(base+"/size")) continue;
        DiskInfo x; x.name="/dev/"+n;
        x.size=(uint64_t)std::strtoull(firstLine(base+"/size").c_str(),0,10)*512ULL;
        std::string removable=firstLine(base+"/removable");
        std::string rotational=firstLine(base+"/queue/rotational");
        if(removable=="1") x.type="Removable";
        else if(rotational=="1") x.type="HDD";
        else if(rotational=="0") x.type="SSD";
        else x.type="Unknown";
        x.model=firstLine(base+"/device/model");
        if(x.model.empty()) x.model=firstLine(base+"/device/name");
        DIR *pd=opendir(base.c_str());
        if(pd){
            struct dirent *pe;
            while((pe=readdir(pd))){
                std::string pn=pe->d_name;
                if(pn=="."||pn=="..") continue;
                std::string pp=base+"/"+pn;
                if(pn.rfind(n,0)==0 && exists(pp+"/partition")) x.partitions.push_back(pn);
            }
            closedir(pd);
        }
        std::sort(x.partitions.begin(),x.partitions.end());
        out.push_back(x);
    }
    closedir(d);
    std::sort(out.begin(),out.end(),[](const DiskInfo&a,const DiskInfo&b){return a.name<b.name;});
    return out;
}
static std::string mountPointFor(const std::string &dev){
    FILE *f=setmntent("/proc/self/mounts","r"); if(!f) return "";
    struct mntent *m; std::string result;
    while((m=getmntent(f))){
        if(m->mnt_fsname==dev){ result=m->mnt_dir; break; }
    }
    endmntent(f); return result;
}
static std::string fsFor(const std::string &dev){
    FILE *f=setmntent("/proc/self/mounts","r"); if(!f) return "";
    struct mntent *m; std::string result;
    while((m=getmntent(f))){ if(m->mnt_fsname==dev){ result=m->mnt_type; break; } }
    endmntent(f); return result;
}
static uint64_t freeFor(const std::string &mount){
    if(mount.empty()) return 0; struct statvfs v;
    if(statvfs(mount.c_str(),&v)!=0) return 0;
    return (uint64_t)v.f_bavail*(uint64_t)v.f_frsize;
}
static uint64_t sizeForPartition(const std::string &dev){
    std::string n=dev.substr(dev.find_last_of('/')+1);
    return (uint64_t)std::strtoull(firstLine("/sys/class/block/"+n+"/size").c_str(),0,10)*512ULL;
}
static std::string mountedDeviceFor(const std::string &mountPoint){
    FILE *f=setmntent("/proc/self/mounts","r"); if(!f) return "";
    struct mntent *m; std::string result;
    while((m=getmntent(f))){ if(std::string(m->mnt_dir)==mountPoint){ result=m->mnt_fsname; break; } }
    endmntent(f);
    return result;
}
static std::string parentDiskName(const std::string &dev){
    std::string base=dev.substr(dev.find_last_of('/')+1);
    char buf[512];
    ssize_t n=readlink(("/sys/class/block/"+base).c_str(),buf,sizeof(buf)-1);
    if(n<=0) return "";
    buf[n]=0;
    std::string target(buf);
    size_t lastSlash=target.find_last_of('/');
    if(lastSlash==std::string::npos) return "";
    std::string parentPath=target.substr(0,lastSlash);
    size_t prevSlash=parentPath.find_last_of('/');
    return prevSlash==std::string::npos?parentPath:parentPath.substr(prevSlash+1);
}
static uint64_t nvidiaSmiVram(const std::string &want){
    size_t wc=want.find(':');
    if(wc==std::string::npos) return 0;
    unsigned long wantDomain=std::strtoul(want.substr(0,wc).c_str(),0,16);
    std::string wantRest=want.substr(wc+1);
    std::string out=command("nvidia-smi --query-gpu=pci.bus_id,memory.total --format=csv,noheader,nounits 2>/dev/null");
    std::istringstream in(out); std::string line;
    while(std::getline(in,line)){
        size_t comma=line.find(',');
        if(comma==std::string::npos) continue;
        std::string id=lower(trim(line.substr(0,comma)));
        size_t ic=id.find(':');
        if(ic==std::string::npos) continue;
        if(std::strtoul(id.substr(0,ic).c_str(),0,16)!=wantDomain || id.substr(ic+1)!=wantRest) continue;
        double mib=std::atof(trim(line.substr(comma+1)).c_str());
        return mib>0?(uint64_t)(mib*1024.0*1024.0):0;
    }
    return 0;
}
static uint64_t vmwareSvgaVram(const std::string &want){
    std::string base=std::string("/sys/bus/pci/devices/")+want;
    if(trim(readFile(base+"/device"))!="0x0405") return 0;
    std::istringstream in(readFile(base+"/resource")); std::string line;
    for(int bar=0; std::getline(in,line); ++bar){
        if(bar!=1) continue;
        unsigned long long start=0,end=0,flags=0;
        if(std::sscanf(line.c_str(),"%llx %llx %llx",&start,&end,&flags)!=3) return 0;
        if(!(flags&0x200ULL) || end<start) return 0;
        return (uint64_t)(end-start+1);
    }
    return 0;
}
static uint64_t vramFor(const std::string &slot){
    std::string want=lower(slot);
    if(want.empty()) return 0;
    uint64_t result=0;
    DIR *d=opendir("/sys/class/drm");
    if(d){
        struct dirent *e;
        while((e=readdir(d))){
            std::string n=e->d_name;
            if(n.size()<5 || n.compare(0,4,"card")!=0 || n.find('-')!=std::string::npos) continue;
            std::string dev=std::string("/sys/class/drm/")+n+"/device";
            if(pciAddrOf(dev)!=want) continue;
            std::string x=trim(readFile(dev+"/mem_info_vram_total"));
            if(!x.empty()) result=(uint64_t)std::strtoull(x.c_str(),0,10);
            break;
        }
        closedir(d);
    }
    if(result) return result;

    std::string vendor=trim(readFile(std::string("/sys/bus/pci/devices/")+want+"/vendor"));

    if(vendor=="0x15ad") return vmwareSvgaVram(want);
    if(vendor!="0x10de") return 0;

    d=opendir("/proc/driver/nvidia/gpus");
    if(d){
        struct dirent *e;
        while((e=readdir(d))){
            if(e->d_name[0]=='.') continue;
            if(lower(e->d_name)!=want) continue;
            std::string p=std::string("/proc/driver/nvidia/gpus/")+e->d_name+"/information";
            std::string x=readFile(p); std::string line; std::istringstream in(x);
            while(std::getline(in,line)) if(line.find("Video Memory")!=std::string::npos){
                size_t c=line.find(':'); if(c!=std::string::npos){ std::string v=trim(line.substr(c+1)); double mb=std::atof(v.c_str()); result=(uint64_t)(mb*1024.0*1024.0); break; }
            }
            break;
        }
        closedir(d);
    }
    if(result) return result;

    return nvidiaSmiVram(want);
}
}
namespace SysInfo {
::String getOS(){ return HX_CSTRING("Linux"); }
::String getOSVersion(){ return hx_stringg(osVersion()); }
::String getArchitecture(){ return hx_stringg(architecture()); }
::String getCPUName(){ return hx_stringg(cpuName()); }
int getCPUCoreCount(){ int n=physicalCoreCount(); return n>0?n:(int)sysconf(_SC_NPROCESSORS_ONLN); }
int getCPUThreadCount(){ return (int)sysconf(_SC_NPROCESSORS_ONLN); }
double getTotalRAM(){ struct sysinfo s; return sysinfo(&s)==0?(double)s.totalram*s.mem_unit:0; }
double getAvailableRAM(){ struct sysinfo s; return sysinfo(&s)==0?(double)s.freeram*s.mem_unit:0; }
int getGPUCount(){ return (int)gpus().size(); }
::String getGPUName(int i){ std::vector<GpuInfo> g=gpus(); return i>=0&&i<(int)g.size()?hx_stringg(g[i].name):HX_CSTRING(""); }
double getGPUVRAM(int i){ std::vector<GpuInfo> g=gpus(); return i>=0&&i<(int)g.size()?(double)vramFor(g[i].slot):0; }
::String getManufacturer(){ return hx_stringg(trim(readFile("/sys/devices/virtual/dmi/id/sys_vendor"))); }
::String getModel(){ std::string s=readFile("/sys/devices/virtual/dmi/id/product_name"); return hx_stringg(trim(s)); }
::String getHostname(){ char b[256]; return gethostname(b,sizeof(b))==0?hx_stringg(std::string(b)):HX_CSTRING(""); }
double getUptime(){ std::string s=readFile("/proc/uptime"); return s.empty()?0:std::atof(s.c_str()); }
int getDiskCount(){ return (int)disks().size(); }
::String getDiskName(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].name):HX_CSTRING(""); }
::String getDiskModel(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].model):HX_CSTRING(""); }
::String getDiskType(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?hx_stringg(d[i].type):HX_CSTRING("Unknown"); }
double getDiskSize(int i){ std::vector<DiskInfo>d=disks(); return i>=0&&i<(int)d.size()?(double)d[i].size:0; }
int getPartitionCount(int di){ std::vector<DiskInfo>d=disks(); return di>=0&&di<(int)d.size()?(int)d[di].partitions.size():0; }
::String getPartitionName(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return HX_CSTRING(""); std::string dev="/dev/"+d[di].partitions[pi]; std::string m=mountPointFor(dev); return hx_stringg(m.empty()?dev:m); }
::String getPartitionFileSystem(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return HX_CSTRING(""); return hx_stringg(fsFor("/dev/"+d[di].partitions[pi])); }
double getPartitionSize(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return 0; return (double)sizeForPartition("/dev/"+d[di].partitions[pi]); }
double getPartitionFreeSpace(int di,int pi){ std::vector<DiskInfo>d=disks(); if(di<0||di>=(int)d.size()||pi<0||pi>=(int)d[di].partitions.size()) return 0; return (double)freeFor(mountPointFor("/dev/"+d[di].partitions[pi])); }
int getSystemDiskIndex(){
    std::string dev=mountedDeviceFor("/");
    std::string diskName=dev.empty()?"":parentDiskName(dev);
    if(diskName.empty()) return -1;
    std::vector<DiskInfo>d=disks();
    for(size_t i=0;i<d.size();i++) if(d[i].name=="/dev/"+diskName) return (int)i;
    return -1;
}
}
#endif