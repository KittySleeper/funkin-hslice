#include "SysInfo_Android.h"
#ifdef __ANDROID__
#include <sys/sysinfo.h>
#include <sys/utsname.h>
#include <sys/personality.h>
#include <sys/system_properties.h>
#include <unistd.h>
#include <algorithm>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <dirent.h>
#include <sys/statvfs.h>
#include <mntent.h>
#include <unistd.h>
#include <algorithm>
#include <EGL/egl.h>
#include <GLES2/gl2.h>

namespace {
static ::String hx_stringg(const std::string&s){return ::String::create(s.c_str());}
static std::string prop(const char*k){char b[PROP_VALUE_MAX];int n=__system_property_get(k,b);return n>0?std::string(b,n):std::string();}
static std::string file(const char*p){std::ifstream f(p);if(!f)return "";std::ostringstream s;s<<f.rdbuf();return s.str();}
static std::string cpu(){std::string s=file("/proc/cpuinfo"),line;std::istringstream in(s);while(std::getline(in,line)){size_t p=line.find(':');if(p!=std::string::npos){std::string k=line.substr(0,p);if(k=="Hardware"||k=="model name"||k=="Processor")return line.substr(p+1);}}return prop("ro.board.platform");}
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
static std::string trim(std::string s){size_t a=s.find_first_not_of(" \t\r\n");size_t b=s.find_last_not_of(" \t\r\n");return a==std::string::npos?"":s.substr(a,b-a+1);}
static std::string gpu(){EGLDisplay d=eglGetDisplay(EGL_DEFAULT_DISPLAY);if(d==EGL_NO_DISPLAY)return "";if(!eglBindAPI(EGL_OPENGL_ES_API))return "";EGLint maj,min;if(!eglInitialize(d,&maj,&min))return "";const EGLint cfg[]={EGL_SURFACE_TYPE,EGL_PBUFFER_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,EGL_NONE};EGLConfig c;EGLint n=0;if(!eglChooseConfig(d,cfg,&c,1,&n)||!n){eglTerminate(d);return "";}const EGLint attr[]={EGL_WIDTH,1,EGL_HEIGHT,1,EGL_NONE};EGLSurface s=eglCreatePbufferSurface(d,c,attr);if(s==EGL_NO_SURFACE){eglTerminate(d);return "";}const EGLint ca[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};EGLContext ctx=eglCreateContext(d,c,EGL_NO_CONTEXT,ca);std::string out;if(ctx!=EGL_NO_CONTEXT&&eglMakeCurrent(d,s,s,ctx)){const GLubyte*r=glGetString(GL_RENDERER);if(r)out=(const char*)r;eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);}if(ctx!=EGL_NO_CONTEXT)eglDestroyContext(d,ctx);eglDestroySurface(d,s);eglTerminate(d);return out;}
}
namespace SysInfo {
::String getOS(){return HX_CSTRING("Android");}
::String getOSVersion(){return hx_stringg(prop("ro.build.version.release"));}
::String getArchitecture(){return hx_stringg(architecture());}
::String getCPUName(){return hx_stringg(trim(cpu()));}
int getCPUCoreCount(){long n=sysconf(_SC_NPROCESSORS_CONF);return n>0?(int)n:0;}
int getCPUThreadCount(){long n=sysconf(_SC_NPROCESSORS_ONLN);return n>0?(int)n:0;}
double getTotalRAM(){struct sysinfo s;return sysinfo(&s)==0?(double)s.totalram*s.mem_unit:0;}
double getAvailableRAM(){struct sysinfo s;return sysinfo(&s)==0?(double)s.freeram*s.mem_unit:0;}
int getGPUCount(){return gpu().empty()?0:1;}
::String getGPUName(int i){return i==0?hx_stringg(gpu()):HX_CSTRING("");}
double getGPUVRAM(int i){(void)i;return 0;}
::String getManufacturer(){return hx_stringg(prop("ro.product.manufacturer"));}
::String getModel(){return hx_stringg(prop("ro.product.model"));}
::String getHostname(){char b[256];if(gethostname(b,sizeof(b))==0)return hx_stringg(std::string(b));return hx_stringg(prop("net.hostname"));}
double getUptime(){std::string s=file("/proc/uptime");return s.empty()?0:std::atof(s.c_str());}
struct DiskInfo{std::string name,model,type;uint64_t size;std::vector<std::string> parts;};
static std::string trim2(const std::string&s){size_t a=s.find_first_not_of(" \t\r\n");size_t b=s.find_last_not_of(" \t\r\n");return a==std::string::npos?"":s.substr(a,b-a+1);}
static std::string fline(const std::string&p){return trim2(file(p.c_str()));}
static std::vector<DiskInfo> disks(){std::vector<DiskInfo>o;DIR*d=opendir("/sys/block");if(!d)return o;struct dirent*e;while((e=readdir(d))){std::string n=e->d_name;if(n=="."||n==".."||n.rfind("loop",0)==0||n.rfind("ram",0)==0||n.rfind("zram",0)==0||n.rfind("dm-",0)==0||n.rfind("md",0)==0)continue;std::string b="/sys/block/"+n;if(access((b+"/size").c_str(),F_OK)!=0)continue;DiskInfo x;x.name="/dev/"+n;x.size=(uint64_t)std::strtoull(fline(b+"/size").c_str(),0,10)*512ULL;std::string rem=fline(b+"/removable"),rot=fline(b+"/queue/rotational");x.type=rem=="1"?"Removable":(rot=="1"?"HDD":(rot=="0"?"SSD":"Unknown"));x.model=fline(b+"/device/model");DIR*pd=opendir(b.c_str());if(pd){struct dirent*pe;while((pe=readdir(pd))){std::string pn=pe->d_name;if(pn.rfind(n,0)==0&&access((b+"/"+pn+"/partition").c_str(),F_OK)==0)x.parts.push_back(pn);}closedir(pd);}std::sort(x.parts.begin(),x.parts.end());o.push_back(x);}closedir(d);std::sort(o.begin(),o.end(),[](const DiskInfo&a,const DiskInfo&b){return a.name<b.name;});return o;}
static std::string mount2(const std::string&dev){FILE*f=setmntent("/proc/self/mounts","r");if(!f)return "";struct mntent*m;std::string r;while((m=getmntent(f)))if(m->mnt_fsname==dev){r=m->mnt_dir;break;}endmntent(f);return r;}
static std::string fs2(const std::string&dev){FILE*f=setmntent("/proc/self/mounts","r");if(!f)return "";struct mntent*m;std::string r;while((m=getmntent(f)))if(m->mnt_fsname==dev){r=m->mnt_type;break;}endmntent(f);return r;}
static uint64_t free2(const std::string&m){if(m.empty())return 0;struct statvfs v;if(statvfs(m.c_str(),&v)!=0)return 0;return(uint64_t)v.f_bavail*(uint64_t)v.f_frsize;}
static std::string mountedDevice2(const std::string&mnt){FILE*f=setmntent("/proc/self/mounts","r");if(!f)return "";struct mntent*m;std::string r;while((m=getmntent(f)))if(std::string(m->mnt_dir)==mnt){r=m->mnt_fsname;break;}endmntent(f);return r;}
static std::string parentDiskName2(const std::string&dev){std::string base=dev.substr(dev.find_last_of('/')+1);char buf[512];ssize_t n=readlink(("/sys/class/block/"+base).c_str(),buf,sizeof(buf)-1);if(n<=0)return "";buf[n]=0;std::string target(buf);size_t lastSlash=target.find_last_of('/');if(lastSlash==std::string::npos)return "";std::string parentPath=target.substr(0,lastSlash);size_t prevSlash=parentPath.find_last_of('/');return prevSlash==std::string::npos?parentPath:parentPath.substr(prevSlash+1);}
static uint64_t partSize2(const std::string&dev){std::string n=dev.substr(dev.find_last_of('/')+1);return(uint64_t)std::strtoull(fline("/sys/class/block/"+n+"/size").c_str(),0,10)*512ULL;}
int getDiskCount(){return(int)disks().size();}
::String getDiskName(int i){std::vector<DiskInfo>d=disks();return i>=0&&i<(int)d.size()?hx_stringg(d[i].name):HX_CSTRING("");}
::String getDiskModel(int i){std::vector<DiskInfo>d=disks();return i>=0&&i<(int)d.size()?hx_stringg(d[i].model):HX_CSTRING("");}
::String getDiskType(int i){std::vector<DiskInfo>d=disks();return i>=0&&i<(int)d.size()?hx_stringg(d[i].type):HX_CSTRING("Unknown");}
double getDiskSize(int i){std::vector<DiskInfo>d=disks();return i>=0&&i<(int)d.size()?(double)d[i].size:0;}
int getPartitionCount(int i){std::vector<DiskInfo>d=disks();return i>=0&&i<(int)d.size()?(int)d[i].parts.size():0;}
::String getPartitionName(int i,int j){std::vector<DiskInfo>d=disks();if(i<0||i>=(int)d.size()||j<0||j>=(int)d[i].parts.size())return HX_CSTRING("");std::string dev="/dev/"+d[i].parts[j],m=mount2(dev);return hx_stringg(m.empty()?dev:m);}
::String getPartitionFileSystem(int i,int j){std::vector<DiskInfo>d=disks();if(i<0||i>=(int)d.size()||j<0||j>=(int)d[i].parts.size())return HX_CSTRING("");return hx_stringg(fs2("/dev/"+d[i].parts[j]));}
double getPartitionSize(int i,int j){std::vector<DiskInfo>d=disks();if(i<0||i>=(int)d.size()||j<0||j>=(int)d[i].parts.size())return 0;return(double)partSize2("/dev/"+d[i].parts[j]);}
double getPartitionFreeSpace(int i,int j){std::vector<DiskInfo>d=disks();if(i<0||i>=(int)d.size()||j<0||j>=(int)d[i].parts.size())return 0;return(double)free2(mount2("/dev/"+d[i].parts[j]));}
int getSystemDiskIndex(){
    std::string dev=mountedDevice2("/");
    std::string diskName=dev.empty()?"":parentDiskName2(dev);
    if(diskName.empty()){ dev=mountedDevice2("/data"); diskName=dev.empty()?"":parentDiskName2(dev); }
    if(diskName.empty()) return -1;
    std::vector<DiskInfo>d=disks();
    for(size_t i=0;i<d.size();i++) if(d[i].name=="/dev/"+diskName) return (int)i;
    return -1;
}
}
#endif