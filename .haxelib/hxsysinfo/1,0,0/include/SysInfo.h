#pragma once
#include <stdint.h>
#include <hxcpp.h>

namespace SysInfo {
    ::String getOS();
    ::String getOSVersion();
    ::String getArchitecture();
    ::String getCPUName();
    int getCPUCoreCount();
    int getCPUThreadCount();
    double getTotalRAM();
    double getAvailableRAM();
    int getGPUCount();
    ::String getGPUName(int index);
    double getGPUVRAM(int index);
    ::String getManufacturer();
    ::String getModel();
    ::String getHostname();
    double getUptime();
    int getDiskCount();
    ::String getDiskName(int index);
    ::String getDiskModel(int index);
    ::String getDiskType(int index);
    double getDiskSize(int index);
    int getPartitionCount(int diskIndex);
    ::String getPartitionName(int diskIndex, int partIndex);
    ::String getPartitionFileSystem(int diskIndex, int partIndex);
    double getPartitionSize(int diskIndex, int partIndex);
    double getPartitionFreeSpace(int diskIndex, int partIndex);
    int getSystemDiskIndex();
}
