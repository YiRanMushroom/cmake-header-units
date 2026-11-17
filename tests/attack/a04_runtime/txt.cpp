#include <vector>
#ifdef _ITERATOR_DEBUG_LEVEL
#define A04_IDL _ITERATOR_DEBUG_LEVEL
#else
#define A04_IDL -1   // libstdc++: no such macro
#endif
int txt_size() { return (int)sizeof(std::vector<int>); }
int txt_idl() { return A04_IDL; }
