// #include of a header that has a header unit (translated to an import), next to import std
#include <greet.h>
import std;
int other() { return static_cast<int>(std::string(greet()).size()) + T22_GREET_MACRO; }
