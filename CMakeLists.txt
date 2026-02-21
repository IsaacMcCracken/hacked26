cmake_minimum_required(VERSION 3.13)

# initialize pico-sdk from submodule
# note: this must happen before project()
include(pico-sdk/pico_sdk_init.cmake)

project(RP2040_Zero_Project C CXX ASM)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Add executable. Default name is the project name, version 0.1

add_executable(RP2040_Zero_Project RP2040_Zero_Project.c )

pico_generate_pio_header(RP2040_Zero_Project ${CMAKE_CURRENT_LIST_DIR}/ws2812.pio OUTPUT_DIR ${CMAKE_CURRENT_LIST_DIR}/generated)

pico_set_program_name(RP2040_Zero_Project "RP2040_Zero_Test")
pico_set_program_version(RP2040_Zero_Project "0.1")

pico_enable_stdio_uart(RP2040_Zero_Project 0)
pico_enable_stdio_usb(RP2040_Zero_Project 0)

# Add the standard library to the build
target_link_libraries(RP2040_Zero_Project pico_stdlib)

# Add any user requested libraries
target_link_libraries(RP2040_Zero_Project
        hardware_pio
)

pico_add_extra_outputs(RP2040_Zero_Project)

