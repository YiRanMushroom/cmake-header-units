#pragma once
#ifndef CORE_LEVEL
#error "CORE_LEVEL missing: usage requirements of core not seen"
#endif
#include <fmt/format.h>
#include <string>
inline std::string core_str(int v) { return fmt::format("core{}", v); }
