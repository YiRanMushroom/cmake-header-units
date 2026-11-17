import <vector>;
import <string>;
import <iostream>;

int main() {
  std::vector<std::string> v{"header", "units"};
  std::string joined;
  for (auto const& s : v) joined += s + ' ';
  std::cout << joined << v.size() << '\n';
  return joined == "header units " ? 0 : 1;
}
