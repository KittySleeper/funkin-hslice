#include "../include/SysInfo.h"

#if defined(_WIN32)
#  include "SysInfo_Windows.h"
#elif defined(__ANDROID__)
#  include "SysInfo_Android.h"
#elif defined(__APPLE__)
#  include <TargetConditionals.h>
#  if TARGET_OS_IPHONE
#    include "SysInfo_iOS.h"
#  else
#    include "SysInfo_macOS.h"
#  endif
#elif defined(__linux__)
#  include "SysInfo_Linux.h"
#else
#  error "SysInfo: unsupported platform"
#endif