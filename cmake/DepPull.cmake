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

function(_DepPull_MakeSrcPaths A_DEP_RELATIVE_PATH A_LIST_RELATIVE_PATH)
	set(SOURCE_RELATIVE_PATH "${A_DEP_RELATIVE_PATH}/src")
	set(SOURCE_RELATIVE_PATH "${SOURCE_RELATIVE_PATH}" PARENT_SCOPE)

	set(SOURCE_DIR "${DEPPULL_PATH}/${SOURCE_RELATIVE_PATH}")
	set(SOURCE_DIR "${SOURCE_DIR}" PARENT_SCOPE)

	file(TO_CMAKE_PATH "${A_LIST_RELATIVE_PATH}" LIST_RELATIVE_PATH)
	if(LIST_RELATIVE_PATH AND NOT "${A_LIST_RELATIVE_PATH}" STREQUAL "/")
		set(SOURCE_WITH_LIST_RELATIVE_PATH "${SOURCE_RELATIVE_PATH}/${LIST_RELATIVE_PATH}" PARENT_SCOPE)
		set(LIST_DIR "${SOURCE_DIR}/${LIST_RELATIVE_PATH}" PARENT_SCOPE)
	else()
		set(SOURCE_WITH_LIST_RELATIVE_PATH "${SOURCE_RELATIVE_PATH}" PARENT_SCOPE)
		set(LIST_DIR "${SOURCE_DIR}" PARENT_SCOPE)
	endif()
endfunction()

function(DepPull A_NAME)
	set(oneValueArgs
		USE_PACKAGE
		ARCHIVE_URL
		ARCHIVE_HASH
		GIT_REPO
		GIT_TAG
		LIST_RELATIVE_PATH
	)
	cmake_parse_arguments(A "" "${oneValueArgs}" "" ${ARGN})

	if(A_USE_PACKAGE)
		find_package(${A_NAME} QUIET)
		if(${A_NAME}_FOUND)
			if(DEFINED ${A_NAME}_VERSION)
				message(STATUS "DepPull: found ${A_NAME}@${${A_NAME}_VERSION}")
				return()
			endif()
			message(STATUS "DepPull: found ${A_NAME}")
			return()
		endif()
	endif()

	set(FOUND FALSE)
	string(TOLOWER ${A_NAME} NAME_TOLOWER)

	if(ARCHIVE_URL)
		string(REPLACE "=" "-" DEP_RELATIVE_PATH "${A_ARCHIVE_HASH}")
		set(DEP_RELATIVE_PATH "${NAME_TOLOWER}/${DEP_RELATIVE_PATH}")

		_DepPull_MakeSrcPaths("${DEP_RELATIVE_PATH}" "${A_LIST_RELATIVE_PATH}")

		if(EXISTS "${SOURCE_DIR}.ready")
			set(FOUND TRUE)
		else()
			message(STATUS "DepPull: getting ${A_ARCHIVE_URL}")

			if(EXISTS "${SOURCE_DIR}")
				file(REMOVE_RECURSE "${SOURCE_DIR}")
			endif()
			file(MAKE_DIRECTORY "${SOURCE_DIR}")

			set(SOURCE_PKG "${SOURCE_DIR}.unkpkg")

			if(EXPECTED_HASH)
				file(DOWNLOAD "${ARCHIVE_URL}" "${SOURCE_PKG}" EXPECTED_HASH ${A_ARCHIVE_HASH})
			else()
				file(DOWNLOAD "${ARCHIVE_URL}" "${SOURCE_PKG}")
			endif()

			execute_process(
				COMMAND "${CMAKE_COMMAND}" -E tar xzf "${SOURCE_PKG}"
				RESULT_VARIABLE EXIT_CODE
				WORKING_DIRECTORY "${SOURCE_DIR}"
				ENCODING NONE
			)
			if(EXIT_CODE STREQUAL "0")
				file(WRITE "${SOURCE_DIR}.ready" "")
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
			set(GIT_TAG "${A_GIT_REPO}")
		else()
			set(GIT_TAG "master")
		endif()

		set(DEP_RELATIVE_PATH "${NAME_TOLOWER}/git-${GIT_REPO_NAME}")
		if(NOT "${GIT_TAG}" STREQUAL "master")
			set(DEP_RELATIVE_PATH "${DEP_RELATIVE_PATH}-${GIT_TAG}")
		endif()

		_DepPull_MakeSrcPaths("${DEP_RELATIVE_PATH}" "${A_LIST_RELATIVE_PATH}")

		if(NOT EXISTS "${SOURCE_DIR}.ready")

			if(NOT DEFINED GIT_EXECUTABLE)
				find_package(Git REQUIRED)
			endif()

			message(STATUS "DepPull: cloning ${A_GIT_REPO} (${GIT_TAG})")

			if(NOT EXISTS "${DEPPULL_PATH}")
				file(MAKE_DIRECTORY "${DEPPULL_PATH}")
			endif()

			execute_process(
				COMMAND "${GIT_EXECUTABLE}" clone "${A_GIT_REPO}" "${SOURCE_RELATIVE_PATH}"
				RESULT_VARIABLE EXIT_CODE
				WORKING_DIRECTORY "${DEPPULL_PATH}"
				ENCODING NONE
			)
			if(EXIT_CODE STREQUAL "0")
				if(NOT "${GIT_TAG}" STREQUAL "master")
					execute_process(
						COMMAND "${GIT_EXECUTABLE}" checkout "${GIT_TAG}"
						RESULT_VARIABLE EXIT_CODE
						WORKING_DIRECTORY "${SOURCE_DIR}"
						ENCODING NONE
					)
					if(EXIT_CODE STREQUAL "0")
						if(NOT EXISTS "${SOURCE_DIR}/.gitmodules")
							file(REMOVE_RECURSE "${SOURCE_DIR}/.git")
						endif()

						file(WRITE "${SOURCE_DIR}.ready" "")
						set(FOUND TRUE)
					endif()
				else()
					file(WRITE "${SOURCE_DIR}.ready" "")
					set(FOUND TRUE)
				endif()
			endif()

		elseif("${GIT_TAG}" STREQUAL "master")

			if(NOT DEFINED GIT_EXECUTABLE)
				find_package(Git REQUIRED QUIET)
			endif()

			if(DEFINED GIT_EXECUTABLE)
				message(STATUS "DepPull: pulling ${SOURCE_WITH_LIST_RELATIVE_PATH}")

				execute_process(
					COMMAND "${GIT_EXECUTABLE}" pull
					RESULT_VARIABLE EXIT_CODE
					WORKING_DIRECTORY "${SOURCE_DIR}"
					ENCODING NONE
				)
				if(EXIT_CODE STREQUAL "0")
					file(WRITE "${SOURCE_DIR}.ready" "")
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
		message(FATAL_ERROR "DepPull: not found ${A_NAME}")
	endif()

	message(STATUS "DepPull: using ${SOURCE_WITH_LIST_RELATIVE_PATH}")

	set(BUILD_DIR "${DEPPULL_CURRENT_PATH}/${DEP_RELATIVE_PATH}/build")
	if(EXISTS "${BUILD_DIR}" AND "${SOURCE_DIR}.ready" IS_NEWER_THAN "${BUILD_DIR}")
		file(REMOVE_RECURSE "${BUILD_DIR}")
	endif()

	if(EXISTS "${LIST_DIR}/CMakeLists.txt")
		add_subdirectory("${LIST_DIR}" "${BUILD_DIR}")
	endif()

	set(DEPPULL_${A_NAME}_SOURCE_DIR "${SOURCE_DIR}" PARENT_SCOPE)
	set(DEPPULL_${A_NAME}_LIST_DIR "${LIST_DIR}" PARENT_SCOPE)
	set(DEPPULL_${A_NAME}_BUILD_DIR "${BUILD_DIR}" PARENT_SCOPE)
endfunction()
