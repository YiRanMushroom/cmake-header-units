export module m2;
import <vector>;   // NOT re-exported

export std::vector<int> make_numbers2(int n) { return std::vector<int>(n, 7); }
