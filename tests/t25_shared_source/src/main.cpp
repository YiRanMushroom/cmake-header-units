import <sh.h>;
#include <sh2.h>
static_assert(SH == 1);
int main() { return sh_value() + sh2_value() == 3 ? 0 : 1; }
