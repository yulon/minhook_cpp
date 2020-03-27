cmake_minimum_required(VERSION 3.0 FATAL_ERROR)

if(DEFINED DEPPULL_CURRENT_PATH)
	return()
endif()

set(DEPPULL_CURRENT_PATH "${CMAKE_BINARY_DIR}/DepPull")

if(NOT DEFINED DEPPULL_PATH AND NOT DEFINED CACHE{DEPPULL_PATH})
	if(DEFINED ENV{DEPPULL_PATH})
		set(DEPPULL_PATH "$ENV{DEPPULL_PATH}")
	else()
		set(DEPPULL_PATH "${DEPPULL_CURRENT_PATH}")
	endif()
endif()

string(TOUPPER "${DEPPULL_PATH}" _DEPPULL_PATH_TOUPPER)

if("${_DEPPULL_PATH_TOUPPER}" STREQUAL "IN_HOME")
	if(WIN32)
		set(DEPPULL_PATH "$ENV{USERPROFILE}/.DepPull")
	elseif(UNIX)
		set(DEPPULL_PATH "$ENV{HOME}/.DepPull")
	endif()
elseif("${_DEPPULL_PATH_TOUPPER}" STREQUAL "IN_TEMP")
	if(WIN32)
		set(DEPPULL_PATH "$ENV{TEMP}/.DepPull")
	elseif(UNIX)
		set(DEPPULL_PATH "/tmp/.DepPull")
	endif()
endif()

file(TO_CMAKE_PATH "${DEPPULL_PATH}" DEPPULL_PATH)

message(STATUS "DepPull: DEPPULL_PATH = ${DEPPULL_PATH}")

function(_DepPull_MakeSrcPaths A_DEP_PREFIX A_SOURCE_PREFIX)
	set(SOURCE_ROOT_REL "${A_DEP_PREFIX}/src")
	set(SOURCE_ROOT_REL "${SOURCE_ROOT_REL}" PARENT_SCOPE)

	set(SOURCE_ROOT "${DEPPULL_PATH}/${SOURCE_ROOT_REL}")
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
		DEV_SOURCE_DIR
	)
	cmake_parse_arguments(A "" "${oneValueArgs}" "" ${ARGN})

	set(FOUND FALSE)
	string(TOLOWER ${A_NAME} NAME_TOLOWER)

	if(EXISTS "${A_DEV_SOURCE_DIR}")
		set(SOURCE_DIR "${A_DEV_SOURCE_DIR}")
		set(STORAGE_PREFIX "${NAME_TOLOWER}/dev")
		set(FOUND TRUE)
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

			if(NOT EXISTS "${DEPPULL_PATH}")
				file(MAKE_DIRECTORY "${DEPPULL_PATH}")
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

	set(BUILD_DIR "${DEPPULL_CURRENT_PATH}/${STORAGE_PREFIX}/build")
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
