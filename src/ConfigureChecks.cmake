####### checks for kdecore/kauth ###############

set(KAUTH_BACKEND_NAME "" CACHE STRING "Specifies the KAuth backend to build. Current available options are
                                   PolkitQt${QT_MAJOR_VERSION}-1, Fake, OSX. Not setting this variable will build the most
                                   appropriate backend for your system")

# Case-insensitive
string(TOUPPER "${KAUTH_BACKEND_NAME}" KAUTH_BACKEND_NAME)

set(KAUTH_BACKEND ${KAUTH_BACKEND_NAME})

## Check if the user did not specify a backend to be built. If that is the case,
## we check what is the best backend to build on this system.
if(NOT KAUTH_BACKEND)
    # Look for the most appropriate backend
    message(STATUS "No backend for KAuth was explicitly specified: probing system to find the best one available")
    if(APPLE)
        set(KAUTH_BACKEND "OSX")
    elseif(UNIX)
        find_package(PolkitQt${QT_MAJOR_VERSION}-1 0.99.0)

        if(PolkitQt${QT_MAJOR_VERSION}-1_FOUND)
            set(KAUTH_BACKEND "POLKITQT${QT_MAJOR_VERSION}-1")

            set_package_properties(PolkitQt${QT_MAJOR_VERSION}-1 PROPERTIES
              URL "http://techbase.kde.org/Polkit-Qt-1"
              DESCRIPTION "PolicyKit API for Qt"
              TYPE RECOMMENDED
              PURPOSE "Support for executing privileged actions in a controlled way (KAuth)"
            )
        else()
            set(KAUTH_BACKEND "FAKE")
        endif()
    else()
        set(KAUTH_BACKEND "FAKE")
    endif()

elseif(KAUTH_BACKEND AND NOT KAUTH_BUILD_CODEGENERATOR_ONLY)
    # Check if the specified backend is valid. If it is not, we fall back to the FAKE one
    if(NOT KAUTH_BACKEND STREQUAL "OSX"
        AND NOT KAUTH_BACKEND STREQUAL "POLKITQT"
        AND NOT KAUTH_BACKEND STREQUAL "POLKITQT${QT_MAJOR_VERSION}-1"
        AND NOT KAUTH_BACKEND STREQUAL "FAKE")
        message("WARNING: The KAuth Backend ${KAUTH_BACKEND} you specified does not exist. Falling back to Fake backend")
        set(KAUTH_BACKEND "FAKE")
    endif()

    # Check requirements for each backend. If not, fall back to the fake one
    if(KAUTH_BACKEND STREQUAL "OSX" AND NOT APPLE)
        message("WARNING: You chose the OSX KAuth backend but your system does not support it. Falling back to Fake backend")
        set(KAUTH_BACKEND "FAKE")
    endif()
    if(KAUTH_BACKEND STREQUAL "POLKITQT")
        find_package(PolkitQt)

        set_package_properties(PolkitQt PROPERTIES
          URL "http://api.kde.org/polkit-qt"
          DESCRIPTION "PolicyKit API for Qt"
          TYPE RECOMMENDED
          PURPOSE "Support for executing privileged actions in a controlled way (KAuth). Either this or PolkitQt${QT_MAJOR_VERSION}-1 is required to make KAuth work, and hence enable certain workspace functionalities"
        )
        if(NOT POLKITQT_FOUND)
            message("WARNING: You chose the PolkitQt KAuth backend but you don't have PolkitQt installed.
                      Falling back to Fake backend")
            set(KAUTH_BACKEND "FAKE")
        endif()
    endif()
    if(KAUTH_BACKEND STREQUAL "POLKITQT${QT_MAJOR_VERSION}-1")
        find_package(PolkitQt${QT_MAJOR_VERSION}-1 0.99.0)
        set_package_properties(PolkitQt${QT_MAJOR_VERSION}-1 PROPERTIES
          URL "http://techbase.kde.org/Polkit-Qt-1"
          DESCRIPTION "PolicyKit API for Qt"
          TYPE RECOMMENDED
          PURPOSE "Support for executing privileged actions in a controlled way (KAuth). Either this or PolkitQt is required to make KAuth work, and hence enable certain workspace functionalities"
        )
        if(NOT PolkitQt${QT_MAJOR_VERSION}-1_FOUND)
            message("WARNING: You chose the PolkitQt${QT_MAJOR_VERSION}-1 KAuth backend but you don't have PolkitQt${QT_MAJOR_VERSION}-1 installed.
                      Falling back to Fake backend")
            set(KAUTH_BACKEND "FAKE")
        endif()
    endif()
endif()

set(KAUTH_BACKEND_NAME ${KAUTH_BACKEND} CACHE STRING "Specifies the KAuth backend to build. Current available options are
                                   PolkitQt, PolkitQt${QT_MAJOR_VERSION}-1, Fake, OSX. Not setting this variable will build the most
                                   appropriate backend for your system" FORCE)

# Add the correct libraries depending on the backend, and eventually set the policy files install location
if(KAUTH_BACKEND_NAME STREQUAL "OSX")
    find_library(CORE_FOUNDATION_LIBRARY CoreFoundation)
    find_library(SECURITY_LIBRARY Security)

    message(STATUS "Building OSX KAuth backend")

    set(KAUTH_BACKEND_SRCS
        backends/mac/AuthServicesBackend.cpp
    )

    set(KAUTH_BACKEND_LIBS ${SECURITY_LIBRARY} Qt${QT_MAJOR_VERSION}::Core)
elseif(KAUTH_BACKEND_NAME STREQUAL "POLKITQT${QT_MAJOR_VERSION}-1")
    message(STATUS "Building PolkitQt${QT_MAJOR_VERSION}-1 KAuth backend")

    include_directories(SYSTEM ${POLKITQT-1_INCLUDE_DIR})

    set(KAUTH_BACKEND_SRCS
        backends/polkit-1/Polkit1Backend.cpp
    )

    set(KAUTH_BACKEND_LIBS ${POLKITQT-1_CORE_LIBRARY} Qt${QT_MAJOR_VERSION}::DBus Qt${QT_MAJOR_VERSION}::Widgets KF5::AuthCore)

    # POLKITQT-1_POLICY_FILES_INSTALL_DIR has an absolute pathname, fix that.
    if(PolkitQt${QT_MAJOR_VERSION}-1_FOUND)
        string(REPLACE ${POLKITQT-1_INSTALL_DIR}
            ${CMAKE_INSTALL_PREFIX} _KAUTH_POLICY_FILES_INSTALL_DIR
            ${POLKITQT-1_POLICY_FILES_INSTALL_DIR})
    endif()

    set(KAUTH_POLICY_FILES_INSTALL_DIR ${_KAUTH_POLICY_FILES_INSTALL_DIR} CACHE STRING
        "Where policy files generated by KAuth will be installed" FORCE)
elseif(KAUTH_BACKEND_NAME STREQUAL "FAKE")
    set(KAUTH_COMPILING_FAKE_BACKEND TRUE)

    message(STATUS "Building Fake KAuth backend")
    message("WARNING: No valid KAuth backends will be built. The library will not work properly unless compiled with
             a working backend")
endif()

# KAuth policy generator executable source probing
set(KAUTH_POLICY_GEN_SRCS
    policy-gen/policy-gen.cpp)
set(KAUTH_POLICY_GEN_LIBRARIES)

if(KAUTH_BACKEND_NAME STREQUAL "OSX")
   set(KAUTH_POLICY_GEN_SRCS ${KAUTH_POLICY_GEN_SRCS}
       backends/mac/kauth-policy-gen-mac.cpp)
   set(KAUTH_POLICY_GEN_LIBRARIES ${KAUTH_POLICY_GEN_LIBRARIES} ${CORE_FOUNDATION_LIBRARY} ${SECURITY_LIBRARY} Qt${QT_MAJOR_VERSION}::Core)
elseif(KAUTH_BACKEND_NAME STREQUAL "POLKITQT${QT_MAJOR_VERSION}-1")
  set(KAUTH_POLICY_GEN_SRCS ${KAUTH_POLICY_GEN_SRCS}
      backends/polkit-1/kauth-policy-gen-polkit1.cpp)
  set(KAUTH_POLICY_GEN_LIBRARIES ${KAUTH_POLICY_GEN_LIBRARIES}
      Qt${QT_MAJOR_VERSION}::Core)
endif()

########################
# Helper backend probing

set(KAUTH_HELPER_BACKEND_NAME "" CACHE STRING "Specifies the KAuth helper backend to build. Current available options are
                                   DBus, Fake. Not setting this variable will build the most appropriate backend for your system")

set(KAUTH_HELPER_BACKEND ${KAUTH_HELPER_BACKEND_NAME})

if(NOT KAUTH_HELPER_BACKEND)
    # No checks needed, just set the dbus backend
    set(KAUTH_HELPER_BACKEND "DBus")
    string(TOUPPER ${KAUTH_HELPER_BACKEND} KAUTH_HELPER_BACKEND_UPPER)
    set(KAUTH_HELPER_BACKEND ${KAUTH_HELPER_BACKEND_UPPER})
else()
    # No checks needed here either
    string(TOUPPER ${KAUTH_HELPER_BACKEND} KAUTH_HELPER_BACKEND_UPPER)
    set(KAUTH_HELPER_BACKEND ${KAUTH_HELPER_BACKEND_UPPER})
endif()

set(KAUTH_HELPER_BACKEND_NAME ${KAUTH_HELPER_BACKEND} CACHE STRING "Specifies the KAuth helper backend to build. Current
                                                            available options are DBus, Fake. Not setting this variable will
                                                            build the most appropriate backend for your system" FORCE)

# Add the correct libraries/files depending on the backend
if(KAUTH_HELPER_BACKEND_NAME STREQUAL "DBUS")
    qt_add_dbus_adaptor(kauth_dbus_adaptor_SRCS
                        backends/dbus/org.kde.kf5auth.xml
                        backends/dbus/DBusHelperProxy.h
                        KAuth::DBusHelperProxy)

    set(KAUTH_HELPER_BACKEND_SRCS
        backends/dbus/DBusHelperProxy.cpp
        ${kauth_dbus_adaptor_SRCS}
    )

    set(KAUTH_HELPER_BACKEND_LIBS Qt${QT_MAJOR_VERSION}::DBus KF5::Auth KF5::AuthCore)

    # Install some files as well
    install(FILES backends/dbus/org.kde.kf5auth.conf
             DESTINATION ${KDE_INSTALL_DBUSDIR}/system.d)

    install(FILES backends/dbus/dbus_policy.stub
                   backends/dbus/dbus_service.stub
             DESTINATION ${KDE_INSTALL_DATADIR_KF}/kauth COMPONENT Devel)
elseif(KAUTH_HELPER_BACKEND_NAME STREQUAL "FAKE")
    message("WARNING: No valid KAuth helper backends will be built. The library will not work properly unless compiled with
             a working backend")
endif()


# Set directories for plugins
if(NOT WIN32)

  # ###
  # WARNING Copied from KDE4Internal. Decide whether this should be fixed in
  # CMake or in ECM:
  # ###

  # This macro implements some very special logic how to deal with the cache.
  # By default the various install locations inherit their value from their "parent" variable
  # so if you set CMAKE_INSTALL_PREFIX, then EXEC_INSTALL_PREFIX, PLUGIN_INSTALL_DIR will
  # calculate their value by appending subdirs to CMAKE_INSTALL_PREFIX .
  # This would work completely without using the cache.
  # But if somebody wants e.g. a different EXEC_INSTALL_PREFIX this value has to go into
  # the cache, otherwise it will be forgotten on the next cmake run.
  # Once a variable is in the cache, it doesn't depend on its "parent" variables
  # anymore and you can only change it by editing it directly.
  # this macro helps in this regard, because as long as you don't set one of the
  # variables explicitly to some location, it will always calculate its value from its
  # parents. So modifying CMAKE_INSTALL_PREFIX later on will have the desired effect.
  # But once you decide to set e.g. EXEC_INSTALL_PREFIX to some special location
  # this will go into the cache and it will no longer depend on CMAKE_INSTALL_PREFIX.
  #
  # additionally if installing to the same location as kdelibs, the other install
  # directories are reused from the installed kdelibs
  macro(_SET_FANCY _var _value _comment)
    set(predefinedvalue "${_value}")
    if(NOT DEFINED ${_var})
        set(${_var} ${predefinedvalue})
    else()
        set(${_var} "${${_var}}" CACHE PATH "${_comment}")
    endif()
  endmacro()

  _set_fancy(KAUTH_HELPER_PLUGIN_DIR "kauth/helper" "Where KAuth's helper plugin will be installed")
  _set_fancy(KAUTH_BACKEND_PLUGIN_DIR "kauth/backend" "Where KAuth's backend plugin will be installed")
  #set(KAUTH_OTHER_PLUGIN_DIR "${QT_PLUGINS_DIR}/kauth/plugins")
else()
  set(KAUTH_HELPER_PLUGIN_DIR "kauth/helper")
  set(KAUTH_BACKEND_PLUGIN_DIR "kauth/backend")
endif()

## End
