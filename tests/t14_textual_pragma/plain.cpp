// HeaderUnits pragma: textual-includes
#include <stbish/stbish.h>
#include <vector>
int plain_value() { std::vector<int> v{stbish_value()}; return v[0]; }
