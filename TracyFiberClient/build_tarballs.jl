# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "TracyFiberClient"
version = v"0.12.2"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/wolfpld/tracy.git",
              "c556831ddc6fe26d2fce01c14c97205a9dad46d5"), # v0.12.2
]

# Bash recipe for building across all platforms
script = raw"""
cd ${WORKSPACE}/srcdir/tracy
meson setup build --cross-file="${MESON_TARGET_TOOLCHAIN}" --buildtype=release \
                  --prefix=$prefix \
                  -Ddelayed_init=true \
                  -Dmanual_lifetime=true \
                  -Dfibers=true \
                  -Donly_localhost=true \
                  -Dno_broadcast=true \
                  -Dno_code_transfer=true \
                  -Dno_sampling=true \
                  -Dno_callstack=true \
                  -Dno_vsync_capture=true \
                  -Dno_frame_image=true \
                  -Dno_crash_handler=true \
                  -Dcpp_args='-D__STDC_FORMAT_MACROS'
                #   -Dverbose \
                #   -Ddebuginfod \
                #   -Dlibunwind_backtrace=true \
                #   -Dtimer_fallback=true \
meson compile -C build -j${nproc}
meson install -C build
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
# platforms = [Platform("x86_64", "linux")]
platforms = supported_platforms()

# The products that we will ensure are always built
products = [
    LibraryProduct("libtracy", :libtracy),
]

# Dependencies that must be installed before this package can be built
dependencies = Dependency[
    Dependency("CompilerSupportLibraries_jll"),
]

# Build the tarballs, and possibly a `build.jl` as well
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version=v"8", clang_use_lld=false)
