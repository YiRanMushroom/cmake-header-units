import <vector>;
import <fmt/format.h>;
import <mylib/api.h>;
import "local.h";
#ifdef HU_T08_NEVER_DEFINED
import <hu_t08_does_not_exist.h>;   // inactive branch: must be skipped, not an error
#endif
int other();
int main() {
  std::vector<int> v = local_vec();
  std::string s = fmt::format("{}-{}", mylib_name(), v.size());
  return (s == "mylib-2" && MYLIB_VERSION == 3 && LOCAL_MACRO == 2 && other() == 5) ? 0 : 1;
}
