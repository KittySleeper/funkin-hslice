#include "SysInfo_iOS.h"
#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <mach/mach.h>
#include <UIKit/UIDevice.h>
#include <Metal/Metal.h>
#include <string>
#include <vector>
#include <sstream>
#include <ctime>
namespace { static ::String hx_stringg(const std::string&s){return ::String::create(s.c_str());} static std::string sysctlString(const char*k){size_t n=0;if(sysctlbyname(k,0,&n,0,0)!=0||!n)return "";std::string s(n,'\0');if(sysctlbyname(k,&s[0],&n,0,0)!=0)return "";if(!s.empty()&&s.back()=='\0')s.pop_back();return s;} static uint64_t u64(const char*k){uint64_t v=0;size_t n=8;return sysctlbyname(k,&v,&n,0,0)==0?v:0;} static double available(){mach_msg_type_number_t c=HOST_VM_INFO64_COUNT;vm_statistics64_data_t v;if(host_statistics64(mach_host_self(),HOST_VM_INFO64,(host_info64_t)&v,&c)!=KERN_SUCCESS)return 0;return(double)(v.free_count+v.inactive_count)*vm_kernel_page_size;} }
namespace SysInfo {
::String getOS(){return HX_CSTRING("iOS");}
::String getOSVersion(){return hx_stringg([[UIDevice currentDevice] systemVersion].UTF8String);}
::String getArchitecture(){struct utsname u;return uname(&u)==0?hx_stringg(u.machine):HX_CSTRING("");}
::String getCPUName(){std::string s=sysctlString("machdep.cpu.brand_string");if(s.empty())s=sysctlString("hw.machine");return hx_stringg(s);}
int getCPUCoreCount(){int n=(int)u64("hw.physicalcpu");return n?n:(int)u64("hw.ncpu");}
int getCPUThreadCount(){int n=(int)u64("hw.logicalcpu");return n?n:(int)u64("hw.ncpu");}
double getTotalRAM(){return(double)[[NSProcessInfo processInfo] physicalMemory];}
double getAvailableRAM(){return available();}
int getGPUCount(){id<MTLDevice>d=MTLCreateSystemDefaultDevice();return d?1:0;}
::String getGPUName(int i){if(i!=0)return HX_CSTRING("");id<MTLDevice>d=MTLCreateSystemDefaultDevice();return d?hx_stringg([[d name] UTF8String]):HX_CSTRING("");}
double getGPUVRAM(int i){(void)i;return 0;}
::String getManufacturer(){return HX_CSTRING("Apple");}
::String getModel(){std::string s=sysctlString("hw.machine");if(s.empty())s=[[UIDevice currentDevice] model].UTF8String;return hx_stringg(s);}
::String getHostname(){return hx_stringg([[UIDevice currentDevice] name].UTF8String);}
double getUptime(){return [[NSProcessInfo processInfo] systemUptime];}
int getDiskCount(){return 0;}
::String getDiskName(int i){(void)i;return HX_CSTRING("");}
::String getDiskModel(int i){(void)i;return HX_CSTRING("");}
::String getDiskType(int i){(void)i;return HX_CSTRING("Unknown");}
double getDiskSize(int i){(void)i;return 0;}
int getPartitionCount(int i){(void)i;return 0;}
::String getPartitionName(int i,int j){(void)i;(void)j;return HX_CSTRING("");}
::String getPartitionFileSystem(int i,int j){(void)i;(void)j;return HX_CSTRING("");}
double getPartitionSize(int i,int j){(void)i;(void)j;return 0;}
double getPartitionFreeSpace(int i,int j){(void)i;(void)j;return 0;}
int getSystemDiskIndex(){return -1;}
}
#endif
#endif