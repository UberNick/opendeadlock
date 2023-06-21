find_package(ImageMagick COMPONENTS Magick++)

# Set the include dir variables and the libraries and let libfind_process do the rest.
# NOTE: Singular variables for this library, plural for libraries this this lib depends on.
set(Magick++_PROCESS_INCLUDES Magick++_INCLUDE_DIR Magick_INCLUDE_DIRS)
set(Magick++_PROCESS_LIBS Magick++_LIBRARY Magick_LIBRARIES)

if (Magick++_FOUND)
  add_definitions(-DWITH_MAGICKPP) 
endif (Magick++_FOUND)
#added locally
add_library(magick magick.h magick.cpp)
