import <tinydep/tiny.h>;
import <gen_config.h>;
int other();
int main() { return (tiny_val() == 9 && TINYDEP_MACRO == 5 && GEN_VALUE == 3 && other() == 8) ? 0 : 1; }
