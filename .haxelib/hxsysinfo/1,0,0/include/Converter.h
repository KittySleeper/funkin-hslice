#pragma once
#include <stdint.h>
#include <hxcpp.h>

namespace Converter {
    double toBit(double bytes, int decimal = 0);
    double toKiB(double bytes, int decimal = 0);
    double toMiB(double bytes, int decimal = 0);
    double toGiB(double bytes, int decimal = 0);
    double toTiB(double bytes, int decimal = 0);
    double toPiB(double bytes, int decimal = 0);
    double toEiB(double bytes, int decimal = 0);
    double toZiB(double bytes, int decimal = 0);
    double toYiB(double bytes, int decimal = 0);
    double toRiB(double bytes, int decimal = 0);
    double toQiB(double bytes, int decimal = 0);
}