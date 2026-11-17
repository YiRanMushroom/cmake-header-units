#pragma once
export import <vector>;
export import "b.h";
#define A_MACRO 1
inline std::vector<int> a_vec() { return {b_val()}; }
