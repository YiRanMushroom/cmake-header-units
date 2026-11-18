// HeaderUnits pragma: textual-includes
#define STBISH_IMPLEMENTATION
#include <stbish/stbish.h>
import <vector>;   // this source's own import still uses the header unit
int impl_size() { std::vector<int> v{1}; return static_cast<int>(v.size()); }
