import <config.h>;
import <vector>;
int main() { std::vector<int> v{cfg()}; return (v[0] == 2 && CFG_VALUE == 2) ? 0 : 1; }
