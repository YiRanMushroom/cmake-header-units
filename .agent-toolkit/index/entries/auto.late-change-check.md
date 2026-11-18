+++
title = "The \"changed after its header units were set up\" warning compares target properties; unset ones read as NOTFOUND"
keys = [ "auto", "deferred", "notfound", "warning" ]
updated = "2026-11-18 21:17:31"
checked = "2026-11-18"

[[links]]
path = "cmake/HeaderUnits/Auto.cmake"
snippet = "if(now MATCHES \"-NOTFOUND$\")"
+++
_hu_auto_run snapshots SOURCES, LINK_LIBRARIES, INCLUDE_DIRECTORIES, COMPILE_DEFINITIONS, COMPILE_OPTIONS and CXX_STANDARD; _hu_auto_finish compares them at the end of the top directory. get_target_property gives "<var>-NOTFOUND" for an unset property, naming the variable, so a snapshot read into v and a comparison read into now always differed: both sides now turn NOTFOUND into "". Any new comparison of target properties needs the same.