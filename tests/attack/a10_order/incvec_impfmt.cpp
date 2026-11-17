#include <vector>
import <fmt/format.h>;
int f() { std::vector<int> v{1, 2}; return (int)fmt::format("{}", v.size()).size(); }
