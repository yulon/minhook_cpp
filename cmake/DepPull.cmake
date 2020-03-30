cmake_minimum_required(VERSION 3.0 FATAL_ERROR)

if(DEFINED _DEFAULT_DEPPULL_CACHE)
	return()
endif()

set(_DEFAULT_DEPPULL_CACHE "${CMAKE_BINARY_DIR}/DepPull")

if(NOT DEFINED DEPPULL_CACHE)
	if(DEFINED CACHE{DEPPULL_CACHE})
		set(DEPPULL_CACHE "$CACHE{DEPPULL_CACHE}")
	elseif(DEFINED ENV{DEPPULL_CACHE})
		set(DEPPULL_CACHE "$ENV{DEPPULL_CACHE}")
	else()
		set(DEPPULL_CACHE "${_DEFAULT_DEPPULL_CACHE}")
	endif()
endif()

string(TOUPPER "${DEPPULL_CACHE}" _DEPPULL_PATH_TOUPPER)

if("${_DEPPULL_PATH_TOUPPER}" STREQUAL "IN_HOME")
	if(WIN32)
		set(DEPPULL_CACHE "$ENV{USERPROFILE}/.DepPull")
	elseif(UNIX)
		set(DEPPULL_CACHE "$ENV{HOME}/.DepPull")
	endif()
elseif("${_DEPPULL_PATH_TOUPPER}" STREQUAL "IN_TEMP")
	if(WIN32)
		set(DEPPULL_CACHE "$ENV{TEMP}/.DepPull")
	elseif(UNIX)
		set(DEPPULL_CACHE "/tmp/.DepPull")
	endif()
endif()

file(TO_CMAKE_PATH "${DEPPULL_CACHE}" DEPPULL_CACHE)

message(STATUS "DepPull: DEPPULL_CACHE = ${DEPPULL_CACHE}")

if(NOT DEFINED DEPPULL_DEV)
	if(DEFINED CACHE{DEPPULL_DEV})
		set(DEPPULL_DEV "$CACHE{DEPPULL_DEV}")
	elseif(DEFINED ENV{DEPPULL_DEV})
		set(DEPPULL_DEV "$ENV{DEPPULL_DEV}")
	else()
		set(DEPPULL_DEV "")
	endif()
endif()

if(DEPPULL_DEV)
	file(TO_CMAKE_PATH "${DEPPULL_DEV}" DEPPULL_DEV)
	message(STATUS "DepPull: DEPPULL_DEV = ${DEPPULL_DEV}")
endif()

function(_DepPull_MakeSrcPaths A_DEP_PREFIX A_SOURCE_PREFIX)
	set(SOURCE_ROOT_REL "${A_DEP_PREFIX}/src")
	set(SOURCE_ROOT_REL "${SOURCE_ROOT_REL}" PARENT_SCOPE)

	set(SOURCE_ROOT "${DEPPULL_CACHE}/${SOURCE_ROOT_REL}")
	set(SOURCE_ROOT "${SOURCE_ROOT}" PARENT_SCOPE)

	file(TO_CMAKE_PATH "${A_SOURCE_PREFIX}" SOURCE_PREFIX)
	if(SOURCE_PREFIX AND NOT "${A_SOURCE_PREFIX}" STREQUAL "/")
		set(SOURCE_DIR_REL "${SOURCE_ROOT_REL}/${SOURCE_PREFIX}" PARENT_SCOPE)
		set(SOURCE_DIR "${SOURCE_ROOT}/${SOURCE_PREFIX}" PARENT_SCOPE)
	else()
		set(SOURCE_DIR_REL "${SOURCE_ROOT_REL}" PARENT_SCOPE)
		set(SOURCE_DIR "${SOURCE_ROOT}" PARENT_SCOPE)
	endif()
endfunction()

function(DepPull A_NAME)
	message(STATUS "DepPull: Checking '${A_NAME}' ...")

	set(oneValueArgs
		USE_PACKAGE
		ARCHIVE_URL
		ARCHIVE_HASH
		GIT_REPO
		GIT_TAG
		SOURCE_PREFIX
	)
	cmake_parse_arguments(A "" "${oneValueArgs}" "" ${ARGN})

	set(FOUND FALSE)
	string(TOLOWER ${A_NAME} NAME_TOLOWER)

	if(DEPPULL_DEV)
		set(SOURCE_DIR "${DEPPULL_DEV}/${A_NAME}")
		if(EXISTS "${SOURCE_DIR}")
			set(STORAGE_PREFIX "${NAME_TOLOWER}/dev")
			set(FOUND TRUE)
		else()
			set(SOURCE_DIR "${DEPPULL_DEV}/${NAME_TOLOWER}")
			if(EXISTS "${SOURCE_DIR}")
				set(STORAGE_PREFIX "${NAME_TOLOWER}/dev")
				set(FOUND TRUE)
			endif()
		endif()
	endif()

	if(NOT FOUND AND A_USE_PACKAGE)
		find_package(${A_NAME} QUIET)
		if(${A_NAME}_FOUND)
			if(DEFINED ${A_NAME}_VERSION)
				message(STATUS "DepPull: Found '${A_NAME}@${${A_NAME}_VERSION}'")
				return()
			endif()
			message(STATUS "DepPull: Found '${A_NAME}'")
			return()
		endif()
	endif()

	if(NOT FOUND AND ARCHIVE_URL)
		string(MAKE_C_IDENTIFIER "${A_ARCHIVE_HASH}" ARCHIVE_NAME)
		set(STORAGE_PREFIX "${NAME_TOLOWER}/${ARCHIVE_NAME}")

		_DepPull_MakeSrcPaths("${STORAGE_PREFIX}" "${A_SOURCE_PREFIX}")

		if(EXISTS "${SOURCE_ROOT}.ready")
			set(FOUND TRUE)
		else()
			if(EXISTS "${SOURCE_ROOT}")
				file(REMOVE_RECURSE "${SOURCE_ROOT}")
			endif()
			file(MAKE_DIRECTORY "${SOURCE_ROOT}")

			set(SOURCE_PKG "${SOURCE_ROOT}.unkpkg")

			if(EXPECTED_HASH)
				file(DOWNLOAD "${ARCHIVE_URL}" "${SOURCE_PKG}" EXPECTED_HASH ${A_ARCHIVE_HASH})
			else()
				file(DOWNLOAD "${ARCHIVE_URL}" "${SOURCE_PKG}")
			endif()

			execute_process(
				COMMAND "${CMAKE_COMMAND}" -E tar xzf "${SOURCE_PKG}"
				RESULT_VARIABLE EXIT_CODE
				WORKING_DIRECTORY "${SOURCE_ROOT}"
				ENCODING NONE
			)
			if(EXIT_CODE STREQUAL "0")
				file(WRITE "${SOURCE_ROOT}.ready" "")
				set(FOUND TRUE)
			endif()
			file(REMOVE "${SOURCE_PKG}")
		endif()
	endif()

	if(NOT FOUND AND A_GIT_REPO)
		string(REGEX REPLACE ".+://" "" GIT_REPO_CLEAR "${A_GIT_REPO}")
		string(REGEX REPLACE "\\.git[/\\\\]*$" "" GIT_REPO_CLEAR "${GIT_REPO_CLEAR}")
		string(MAKE_C_IDENTIFIER "${GIT_REPO_CLEAR}" GIT_REPO_NAME)

		if(A_GIT_TAG AND NOT "${A_GIT_TAG}" STREQUAL "*")
			set(GIT_TAG "${A_GIT_TAG}")
		else()
			set(GIT_TAG "master")
		endif()

		set(STORAGE_PREFIX "${NAME_TOLOWER}/${GIT_REPO_NAME}")
		if(NOT "${GIT_TAG}" STREQUAL "master")
			set(STORAGE_PREFIX "${STORAGE_PREFIX}-${GIT_TAG}")
		endif()

		_DepPull_MakeSrcPaths("${STORAGE_PREFIX}" "${A_SOURCE_PREFIX}")

		if(NOT EXISTS "${SOURCE_ROOT}.ready")

			if(NOT DEFINED GIT_EXECUTABLE)
				find_package(Git REQUIRED QUIET)
			endif()

			if(NOT EXISTS "${DEPPULL_CACHE}")
				file(MAKE_DIRECTORY "${DEPPULL_CACHE}")
			endif()

			execute_process(
				COMMAND "${GIT_EXECUTABLE}" clone "${A_GIT_REPO}" "${SOURCE_ROOT}"
				RESULT_VARIABLE EXIT_CODE
				ENCODING NONE
			)
			if(EXIT_CODE STREQUAL "0")
				if(NOT "${GIT_TAG}" STREQUAL "master")
					execute_process(
						COMMAND "${GIT_EXECUTABLE}" checkout "${GIT_TAG}"
						RESULT_VARIABLE EXIT_CODE
						WORKING_DIRECTORY "${SOURCE_ROOT}"
						ENCODING NONE
					)
					if(EXIT_CODE STREQUAL "0")
						if(NOT EXISTS "${SOURCE_ROOT}/.gitmodules")
							file(REMOVE_RECURSE "${SOURCE_ROOT}/.git")
						endif()

						file(WRITE "${SOURCE_ROOT}.ready" "")
						set(FOUND TRUE)
					endif()
				else()
					file(WRITE "${SOURCE_ROOT}.ready" "")
					set(FOUND TRUE)
				endif()
			endif()

		elseif("${GIT_TAG}" STREQUAL "master")

			if(NOT DEFINED GIT_EXECUTABLE)
				find_package(Git REQUIRED QUIET)
			endif()

			if(DEFINED GIT_EXECUTABLE)
				execute_process(
					COMMAND "${GIT_EXECUTABLE}" pull
					RESULT_VARIABLE EXIT_CODE
					WORKING_DIRECTORY "${SOURCE_ROOT}"
					ENCODING NONE
				)
				if(EXIT_CODE STREQUAL "0")
					file(WRITE "${SOURCE_ROOT}.ready" "")
					set(FOUND TRUE)
				endif()
			else()
				set(FOUND TRUE)
			endif()

		else()
			set(FOUND TRUE)
		endif()
	endif()

	if(NOT FOUND)
		message(FATAL_ERROR "DepPull: Not found '${A_NAME}'")
	endif()

	message(STATUS "DepPull: Using '${A_NAME}' at ${SOURCE_DIR}")

	set(BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/DepPull/${STORAGE_PREFIX}/build")
	if(EXISTS "${BUILD_DIR}" AND "${SOURCE_ROOT}.ready" IS_NEWER_THAN "${BUILD_DIR}")
		file(REMOVE_RECURSE "${BUILD_DIR}")
	endif()

	if(EXISTS "${SOURCE_DIR}/CMakeLists.txt")
		add_subdirectory("${SOURCE_DIR}" "${BUILD_DIR}")
	endif()

	set(DEPPULL_${A_NAME}_SOURCE_ROOT "${SOURCE_ROOT}" PARENT_SCOPE)
	set(DEPPULL_${A_NAME}_SOURCE_DIR "${SOURCE_DIR}" PARENT_SCOPE)
	set(DEPPULL_${A_NAME}_BUILD_DIR "${BUILD_DIR}" PARENT_SCOPE)
endfunction()
