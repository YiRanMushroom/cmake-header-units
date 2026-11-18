import <shadow.h>;
import <onlysys.h>;
import <flagsys.h>;
import <cur.h>;
import <vector>;
#ifdef T17_LINKED
import <linked.h>;
static_assert(LINKED == 4, "linked.h through the symbolic link");
#endif
#ifdef NDEBUG
import <relonly.h>;
static_assert(RELONLY == 9, "relonly.h through CMAKE_CXX_FLAGS_RELEASE");
#endif

static_assert(SHADOW == 1, "the first -I directory wins over the second and over -isystem");
static_assert(ONLYSYS == 3, "a header found through the IMPORTED target's -isystem directory");
static_assert(FLAGSYS == 5, "a header found through -isystem in CMAKE_CXX_FLAGS");
static_assert(CURDIR == 6, "a header found through CMAKE_INCLUDE_CURRENT_DIR");

int main() {
  std::vector<int> v{shadow_value(), onlysys_value()};
  return v[0] + v[1] == 4 ? 0 : 1;
}
