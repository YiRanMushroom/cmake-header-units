// Header unit <vector> first, then a textual #include of <string> (overlaps with <vector>'s internals).
import <vector>;
#include <string>

int excluded_fn();  // excluded.cpp

int main() {
  std::vector<std::string> v{"mixed", "tu"};
  return (v.size() == 2 && v[0] + v[1] == "mixedtu" && excluded_fn() == 0) ? 0 : 1;
}
