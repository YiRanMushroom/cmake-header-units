import <shadow.h>;
import <onlysys.h>;
#ifdef T17_LINKED
import <linked.h>;
static_assert(LINKED == 4, "linked.h through the symbolic link");
#endif

static_assert(SHADOW == 1, "the first -I directory wins over the second and over -isystem");
static_assert(ONLYSYS == 3, "a header found through the IMPORTED target's -isystem directory");

int main() { return shadow_value() + onlysys_value() == 4 ? 0 : 1; }
