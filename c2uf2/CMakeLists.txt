
# Boilerplate for invoking the RPP C SDK
cmake_minimum_required(VERSION 3.22)

# Detect/install the raspbery pi pico SDK
include(pico_sdk_import.cmake)

# Give project a name, setup RPP C SDK
project(generic_app)
pico_sdk_init()

# 'Source' files (auto-generated in our case)
add_executable(generic_app
    generic_app.c
)

# Where to fetch the program's dependencies from
target_link_libraries(generic_app pico_stdlib)

# Generate .uf2 file as well as .elf
pico_add_extra_outputs(generic_app)
