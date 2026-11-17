add_library(extra_defs INTERFACE)
target_compile_definitions(extra_defs INTERFACE EXTRA_ON=1)
target_link_libraries(mylib PUBLIC extra_defs)
