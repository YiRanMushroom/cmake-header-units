// Excluded from header units via SOURCES: plain textual includes.
#include <vector>
#include <string>

int excluded_fn() {
  std::vector<std::string> v{"ex", "cluded"};
  return v[0] + v[1] == "excluded" ? 0 : 1;
}
