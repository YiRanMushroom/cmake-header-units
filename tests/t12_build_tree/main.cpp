import <tinydep/tiny.h>;
import <gen_config.h>;
int other();
int gen_src();
int main() { return (tiny_val() == 9 && TINYDEP_MACRO == 5 && GEN_VALUE == 3 && other() == 8 && gen_src() == 6) ? 0 : 1; }
