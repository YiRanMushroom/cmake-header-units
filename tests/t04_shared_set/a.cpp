import <vector>;
import <string>;

int main() {
  std::vector<std::string> v{"a", "b"};
  return v.size() == 2 && v[1] == "b" ? 0 : 1;
}
