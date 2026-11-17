import <mylib/api.h>;
import "local.h";
import <string>;
import <vector>;
int other();
int main() {
  std::vector<int> v = local_vec();
  std::string n = mylib_name();
  return (n == "mylib" && v.size() == 2 && MYLIB_VERSION == 3 && LOCAL_MACRO == 2 && mylib_inline() == 40 && other() == 5) ? 0 : 1;
}
