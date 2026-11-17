import <vector>;
import <string>;
import <iostream>;
import <fmt/format.h>;
import <nlohmann/json.hpp>;
#ifdef HU_HAVE_BOOST
import <boost/optional.hpp>;
#endif

int fmt_only();  // fmt_only.cpp
int both();      // both.cpp

int main() {
  nlohmann::json j = {{"name", "hu"}, {"n", 3}};
  std::vector<int> v{1, 2, 3};
  std::string s = fmt::format("{}:{}:{}", j["name"].get<std::string>(), j["n"].get<int>(), v.size());
#ifdef HU_HAVE_BOOST
  boost::optional<std::string> o = s;
  if (!o || *o != s) return 1;
#endif
  std::cout << s << '\n';
  return (s == "hu:3:3" && fmt_only() == 0 && both() == 0) ? 0 : 1;
}
