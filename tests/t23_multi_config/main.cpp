import <cfgval.h>;
import <vector>;
int other();
int main() {
  std::vector<int> v{cfgval()};
  return (v[0] == T23_EXPECT && other() == T23_BASE + T23_EXPECT) ? 0 : 1;
}
