import std;
import <greet.h>;
int other();
int main() {
  std::vector<int> v{1};
  return (greet().size() + v.size() == 3 && T22_GREET_MACRO == 4 && other() == 6) ? 0 : 1;
}
