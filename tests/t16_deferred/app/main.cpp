import <sub.h>;
import <dep.h>;
import <vector>;
int other();
int main() { std::vector<int> v{SUB_VALUE + DEP_VALUE}; return (v[0] == 7 && other() == 1) ? 0 : 1; }
