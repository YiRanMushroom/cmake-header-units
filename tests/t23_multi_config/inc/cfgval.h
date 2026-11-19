#pragma once
#include <string>
// 1 in a BMI built without NDEBUG (Debug), 2 with it (Release): the header unit of each configuration is its own
inline int cfgval() {
#ifdef NDEBUG
  return 2;
#else
  return 1;
#endif
}
#define T23_BASE 40
