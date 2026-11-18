import <config.h>;
import <vector>;
int main() { std::vector<int> v{cfg()}; return (v[0] == 1 && CFG_VALUE == 1) ? 0 : 1; }
