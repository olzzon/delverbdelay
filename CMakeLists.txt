cmake_minimum_required(VERSION 3.20)

# Read version from package.json if not provided
if(NOT DEFINED PROJECT_VERSION)
    execute_process(
        COMMAND node -p "require('./package.json').version"
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE PROJECT_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(NOT PROJECT_VERSION)
        set(PROJECT_VERSION "1.0.0")
        message(WARNING "Could not read version from package.json, using default: ${PROJECT_VERSION}")
    endif()
endif()

project(DeliVerb VERSION ${PROJECT_VERSION} LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 23)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

# macOS deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Build for Apple Silicon")

# Apple AudioUnitSDK sources (for AUv2)
set(AUSDK_SOURCES
    src/AudioUnitSDK/src/AudioUnitSDK/AUBase.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUBuffer.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUBufferAllocator.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUEffectBase.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUInputElement.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUMIDIBase.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUMIDIEffectBase.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUOutputElement.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUPlugInDispatch.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/AUScopeElement.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/ComponentBase.cpp
    src/AudioUnitSDK/src/AudioUnitSDK/MusicDeviceBase.cpp
)

# DSP source files (header-only)
set(DSP_HEADERS
    src/DSP/Biquad.h
    src/DSP/LFO.h
    src/DSP/DelayLine.h
    src/DSP/Reverb.h
    src/DSP/Ducker.h
    src/DSP/DeliVerbDSP.h
)

# AUv2 wrapper using Apple AudioUnitSDK
set(AUV2_SOURCES
    src/AU/DeliVerbAUv2.mm
    src/AU/DeliVerbCocoaUI.mm
)

# AUv3 sources (Objective-C++)
set(AUV3_SOURCES
    src/AU/DeliVerbAU.mm
    src/AU/DeliVerbAUFactory.mm
)

# UI sources
set(UI_SOURCES
    src/UI/DeliVerbView.mm
    src/UI/Knob.mm
    src/UI/Button.mm
)

# Assets
set(ASSET_FILES
    assets/deliverb.png
)

# App sources
set(APP_SOURCES
    src/App/main.m
    src/App/AppDelegate.m
)

# =============================================================================
# AUv2 Audio Unit Component (.component bundle) - for compatibility
# =============================================================================
add_library(DeliVerbAUv2 MODULE
    ${AUSDK_SOURCES}
    ${AUV2_SOURCES}
    ${UI_SOURCES}
    ${ASSET_FILES}
)

# Mark assets as bundle resources for AUv2
set_source_files_properties(${ASSET_FILES} PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources
)

set_target_properties(DeliVerbAUv2 PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION "component"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Info.plist"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.deliverb.audiounit"
    MACOSX_BUNDLE_BUNDLE_NAME "DeliVerb"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    OUTPUT_NAME "DeliVerb"
    PREFIX ""
)

target_include_directories(DeliVerbAUv2 PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/DSP
    ${CMAKE_SOURCE_DIR}/src/AU
    ${CMAKE_SOURCE_DIR}/src/UI
    ${CMAKE_SOURCE_DIR}/src/AudioUnitSDK/include
)

target_link_libraries(DeliVerbAUv2 PRIVATE
    "-framework AudioToolbox"
    "-framework AudioUnit"
    "-framework CoreAudio"
    "-framework CoreFoundation"
    "-framework Cocoa"
    "-framework Accelerate"
    "-framework CoreAudioKit"
    "-framework QuartzCore"
)

target_compile_options(DeliVerbAUv2 PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-deprecated-declarations
    -fobjc-arc
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Release>:-ffast-math>
)

# =============================================================================
# AUv3 Extension (.appex) - built as module bundle
# =============================================================================
add_library(DeliVerbAU MODULE
    ${AUV3_SOURCES}
    ${UI_SOURCES}
    ${ASSET_FILES}
)

set_target_properties(DeliVerbAU PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION "appex"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Info-Extension.plist"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.deliverb.app.extension"
    MACOSX_BUNDLE_BUNDLE_NAME "DeliVerbAU"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    OUTPUT_NAME "DeliVerbAU"
    PREFIX ""
)

target_include_directories(DeliVerbAU PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/DSP
    ${CMAKE_SOURCE_DIR}/src/AU
    ${CMAKE_SOURCE_DIR}/src/UI
)

target_link_libraries(DeliVerbAU PRIVATE
    "-framework AudioToolbox"
    "-framework AVFoundation"
    "-framework CoreAudioKit"
    "-framework CoreAudio"
    "-framework CoreFoundation"
    "-framework Cocoa"
    "-framework Accelerate"
    "-framework QuartzCore"
)

target_compile_options(DeliVerbAU PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-deprecated-declarations
    -fobjc-arc
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Release>:-ffast-math>
)

# =============================================================================
# Host App (.app) - contains the AUv3 extension
# =============================================================================
add_executable(DeliVerbApp MACOSX_BUNDLE
    ${APP_SOURCES}
)

set_target_properties(DeliVerbApp PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Info-App.plist"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.deliverb.app"
    MACOSX_BUNDLE_BUNDLE_NAME "DeliVerb"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    OUTPUT_NAME "DeliVerb"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_SOURCE_DIR}/DeliVerbApp.entitlements"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "TW59T82MFN"
)

target_include_directories(DeliVerbApp PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/App
)

target_link_libraries(DeliVerbApp PRIVATE
    "-framework Cocoa"
    "-framework AVFoundation"
    "-framework CoreAudioKit"
)

target_compile_options(DeliVerbApp PRIVATE
    -fobjc-arc
)

# =============================================================================
# Post-build: Copy appex into app bundle
# =============================================================================
add_custom_command(TARGET DeliVerbAU POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_BUNDLE_DIR:DeliVerbApp>/Contents/PlugIns"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "$<TARGET_BUNDLE_DIR:DeliVerbAU>"
        "$<TARGET_BUNDLE_DIR:DeliVerbApp>/Contents/PlugIns/DeliVerbAU.appex"
    COMMENT "Copying AUv3 extension into app bundle"
    DEPENDS DeliVerbApp
)

# Ensure app is built before extension tries to copy
add_dependencies(DeliVerbAU DeliVerbApp)
