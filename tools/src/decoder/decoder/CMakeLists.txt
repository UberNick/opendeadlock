cmake_minimum_required (VERSION 2.6)
project (decoder)



find_package(ImageMagick COMPONENTS Magick++)

if (ImageMagick_Magick++_FOUND)  
  include_directories (${DECODER_SOURCE_DIR}/magick)
  include_directories(${ImageMagick_INCLUDE_DIRS})
  add_definitions( -D__WITH_MAGICKPP__ )
  add_executable(decoder decoder.cpp image_decoder/image_decoder.cpp)
endif (ImageMagick_Magick++_FOUND) 

# Subdirectories
if (ImageMagick_Magick++_FOUND)  
add_subdirectory (magick)
endif (ImageMagick_Magick++_FOUND) 
add_subdirectory (xpm_writer)
add_subdirectory (sprite_table_reader)
add_subdirectory (palette_reader)

# Make sure the compiler can find include files.
if (ImageMagick_Magick++_FOUND)  
include_directories (${DECODER_SOURCE_DIR}/magick)
endif (ImageMagick_Magick++_FOUND) 
include_directories (${DECODER_SOURCE_DIR}/palette_reader)
include_directories (${DECODER_SOURCE_DIR}/sprite_table_reader)
include_directories (${DECODER_SOURCE_DIR}/xpm_writer)
include_directories (${DECODER_SOURCE_DIR}/palette_reader)
include_directories (${DECODER_SOURCE_DIR}/sprite_info)
include_directories (${DECODER_SOURCE_DIR}/image_decoder)

# Make sure the linker can find the library once it is built.
if (ImageMagick_Magick++_FOUND)  
link_directories (${DECODER_SOURCE_DIR}/magick)
endif (ImageMagick_Magick++_FOUND) 
link_directories (${DECODER_SOURCE_DIR}/palette_reader)
link_directories (${DECODER_SOURCE_DIR}/sprite_table_reader)
link_directories (${DECODER_SOURCE_DIR}/xpm_writer)
link_directories (${DECODER_SOURCE_DIR}/palette_reader)

if (ImageMagick_Magick++_FOUND)  
  target_link_libraries(decoder palette_reader sprite_table_reader magick xpm_writer ${ImageMagick_LIBRARIES})
  message("-- Generating with ImageMagick.")
else (ImageMagick_Magick++_FOUND)
  message("-- Generating without ImageMagick.")
  target_link_libraries(decoder palette_reader sprite_table_reader xpm_writer ${ImageMagick_LIBRARIES})
  
endif (ImageMagick_Magick++_FOUND) 




