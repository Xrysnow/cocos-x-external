# The bundled GLFW omits its protocol XML directory. Present the original
# sources and the distribution's XML files at the paths expected by GLFW.
function(cc_add_glfw_with_system_protocols)
    find_package(PkgConfig REQUIRED)
    pkg_get_variable(protocols wayland-protocols pkgdatadir)
    pkg_get_variable(core wayland-scanner pkgdatadir)
    set(source "${CMAKE_CURRENT_SOURCE_DIR}/glfw")
    set(overlay "${CMAKE_CURRENT_BINARY_DIR}/glfw-source")
    file(MAKE_DIRECTORY "${overlay}/deps/wayland")
    foreach(entry CMakeLists.txt CMake include src)
        file(CREATE_LINK "${source}/${entry}" "${overlay}/${entry}" SYMBOLIC)
    endforeach()
    foreach(xml
        "${core}/wayland.xml"
        "${protocols}/stable/viewporter/viewporter.xml"
        "${protocols}/stable/xdg-shell/xdg-shell.xml"
        "${protocols}/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml"
        "${protocols}/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml"
        "${protocols}/unstable/relative-pointer/relative-pointer-unstable-v1.xml"
        "${protocols}/staging/fractional-scale/fractional-scale-v1.xml"
        "${protocols}/staging/xdg-activation/xdg-activation-v1.xml"
        "${protocols}/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml")
        get_filename_component(name "${xml}" NAME)
        configure_file("${xml}" "${overlay}/deps/wayland/${name}" COPYONLY)
    endforeach()
    add_subdirectory("${overlay}" glfw)
endfunction()
