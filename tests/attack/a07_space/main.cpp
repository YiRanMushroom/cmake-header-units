import <vector>;
import <sp/sp.hpp>;
int main() { std::vector<int> v{spfn()}; return v[0] == 3 ? 0 : 1; }
