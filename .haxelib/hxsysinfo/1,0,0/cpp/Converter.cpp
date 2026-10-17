#include "../include/Converter.h"
#include <cmath>
#include <iostream>
using namespace std;

namespace {
    static double roundDecimal(double i, int d){if(d == 0)return i; if(d < 0)return round(i); double powed = pow(10, d); return (double)(round(i * powed) / powed); }
}

namespace Converter {
    double toBit(double bytes, int decimal){ return roundDecimal(bytes * 8.0,decimal); }
    double toKiB(double bytes, int decimal){ return roundDecimal(bytes / 1024.0,decimal); }
    double toMiB(double bytes, int decimal){ return roundDecimal(bytes / 1048576.0,decimal); }
    double toGiB(double bytes, int decimal){ return roundDecimal(bytes / 1073741824.0,decimal); }
    double toTiB(double bytes, int decimal){ return roundDecimal(bytes / 1099511627776.0,decimal); }
    double toPiB(double bytes, int decimal){ return roundDecimal(bytes / 1125899906842624.0,decimal); }
    double toEiB(double bytes, int decimal){ return roundDecimal(bytes / 1152921504606846976.0,decimal); }
    double toZiB(double bytes, int decimal){ return roundDecimal(bytes / 1180591620717411303424.0,decimal); }
    double toYiB(double bytes, int decimal){ return roundDecimal(bytes / 1208925819614629174706176.0,decimal); }
    double toRiB(double bytes, int decimal){ return roundDecimal(bytes / 1237940039285380274899124224.0,decimal); }
    double toQiB(double bytes, int decimal){ return roundDecimal(bytes / 1267650600228229401496703205376.0,decimal); }
}