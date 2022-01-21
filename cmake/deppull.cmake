cmake_minimum_required(VERSION 3.0 FATAL_ERROR)

if(DEFINED _DEFAULT_DEPPULL_CACHE)
	return()
endif()

set(_DEFAULT_DEPPULL_CACHE "${CMAKE_BINARY_DIR}/deppull")

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
		set(DEPPULL_CACHE "$ENV{USERPROFILE}/.deppull")
	elseif(UNIX)
		set(DEPPULL_CACHE "$ENV{HOME}/.deppull")
	endif()
elseif("${_DEPPULL_PATH_TOUPPER}" STREQUAL "IN_TEMP")
	if(WIN32)
		set(DEPPULL_CACHE "$ENV{TEMP}/.deppull")
	elseif(UNIX)
		set(DEPPULL_CACHE "/tmp/.deppull")
	endif()
endif()

file(TO_CMAKE_PATH "${DEPPULL_CACHE}" DEPPULL_CACHE)

message(STATUS "deppull: DEPPULL_CACHE = ${DEPPULL_CACHE}")

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
	message(STATUS "deppull: DEPPULL_DEV = ${DEPPULL_DEV}")
endif()

function(_deppull_mkpaths A_STORAGE_PREFIX A_SRC_FIX)
	set(ROOT_REL "${A_STORAGE_PREFIX}/src")
	set(ROOT_REL "${ROOT_REL}" PARENT_SCOPE)

	set(ROOT "${DEPPULL_CACHE}/${ROOT_REL}")
	set(ROOT "${ROOT}" PARENT_SCOPE)

	file(TO_CMAKE_PATH "${A_SRC_FIX}" SRC_FIX)
	if(SRC_FIX AND NOT "${A_SRC_FIX}" STREQUAL "/")
		set(SRC_REL "${ROOT_REL}/${SRC_FIX}" PARENT_SCOPE)
		set(SRC "${ROOT}/${SRC_FIX}" PARENT_SCOPE)
	else()
		set(SRC_REL "${ROOT_REL}" PARENT_SCOPE)
		set(SRC "${ROOT}" PARENT_SCOPE)
	endif()
endfunction()

function(deppull A_NAME)
	if(DEFINED DEPPULL_${A_NAME}_ROOT)
		return()
	endif()

	message(STATUS "deppull: Checking '${A_NAME}' ...")

	set(oneValueArgs
		USE_PACKAGE
		PKG_URL
		PKG_HASH
		GIT_REPO
		GIT_TAG
		SRC_FIX
	)
	cmake_parse_arguments(A "" "${oneValueArgs}" "" ${ARGN})

	set(FOUND FALSE)
	string(TOLOWER ${A_NAME} NAME_TOLOWER)

	if(DEPPULL_DEV)
		set(SRC "${DEPPULL_DEV}/${A_NAME}")
		if(EXISTS "${SRC}")
			set(STORAGE_PREFIX "${NAME_TOLOWER}/dev")
			set(FOUND TRUE)
		else()
			set(SRC "${DEPPULL_DEV}/${NAME_TOLOWER}")
			if(EXISTS "${SRC}")
				set(STORAGE_PREFIX "${NAME_TOLOWER}/dev")
				set(FOUND TRUE)
			endif()
		endif()
	endif()

	if(NOT FOUND AND A_USE_PACKAGE)
		find_package(${A_NAME} QUIET)
		if(${A_NAME}_FOUND)
			if(DEFINED ${A_NAME}_VERSION)
				message(STATUS "deppull: Found '${A_NAME}@${${A_NAME}_VERSION}'")
				return()
			endif()
			message(STATUS "deppull: Found '${A_NAME}'")
			return()
		endif()
	endif()

	if(NOT FOUND AND A_PKG_URL)
		string(MAKE_C_IDENTIFIER "${A_PKG_HASH}" PKG_NAME)
		set(STORAGE_PREFIX "${NAME_TOLOWER}/${PKG_NAME}")

		_deppull_mkpaths("${STORAGE_PREFIX}" "${A_SRC_FIX}")

		if(EXISTS "${ROOT}.ready")
			set(FOUND TRUE)
		else()
			if(EXISTS "${ROOT}")
				file(REMOVE_RECURSE "${ROOT}")
			endif()
			file(MAKE_DIRECTORY "${ROOT}")

			set(PKG_PATH "${ROOT}.unkpkg")

			if(A_PKG_HASH)
				file(DOWNLOAD "${A_PKG_URL}" "${PKG_PATH}" EXPECTED_HASH ${A_PKG_HASH} STATUS DOWNLOAD_STATUS)
			else()
				file(DOWNLOAD "${A_PKG_URL}" "${PKG_PATH}")
			endif()

			list(POP_FRONT DOWNLOAD_STATUS DOWNLOAD_STATUS_CODE)

			if(${DOWNLOAD_STATUS_CODE} EQUAL 0)
				execute_process(
					COMMAND "${CMAKE_COMMAND}" -E tar xzf "${PKG_PATH}"
					RESULT_VARIABLE EXIT_CODE
					WORKING_DIRECTORY "${ROOT}"
					ENCODING NONE
				)
				if(EXIT_CODE STREQUAL "0")
					file(WRITE "${ROOT}.ready" "")
					set(FOUND TRUE)
				endif()
			endif()

			file(REMOVE "${PKG_PATH}")
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

		_deppull_mkpaths("${STORAGE_PREFIX}" "${A_SRC_FIX}")

		if(NOT EXISTS "${ROOT}.ready")

			if(NOT DEFINED GIT_EXECUTABLE)
				find_package(Git REQUIRED QUIET)
			endif()

			if(NOT EXISTS "${DEPPULL_CACHE}")
				file(MAKE_DIRECTORY "${DEPPULL_CACHE}")
			endif()

			execute_process(
				COMMAND "${GIT_EXECUTABLE}" clone "${A_GIT_REPO}" "${ROOT}"
				RESULT_VARIABLE EXIT_CODE
				ENCODING NONE
			)
			if(EXIT_CODE STREQUAL "0")
				if(NOT "${GIT_TAG}" STREQUAL "master")
					execute_process(
						COMMAND "${GIT_EXECUTABLE}" checkout "${GIT_TAG}"
						RESULT_VARIABLE EXIT_CODE
						WORKING_DIRECTORY "${ROOT}"
						ENCODING NONE
					)
					if(EXIT_CODE STREQUAL "0")
						if(NOT EXISTS "${ROOT}/.gitmodules")
							file(REMOVE_RECURSE "${ROOT}/.git")
						endif()

						file(WRITE "${ROOT}.ready" "")
						set(FOUND TRUE)
					endif()
				else()
					file(WRITE "${ROOT}.ready" "")
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
					WORKING_DIRECTORY "${ROOT}"
					ENCODING NONE
				)
				if(EXIT_CODE STREQUAL "0")
					file(WRITE "${ROOT}.ready" "")
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
		message(FATAL_ERROR "deppull: Not found '${A_NAME}'")
	endif()

	message(STATUS "deppull: Using '${A_NAME}' at ${SRC}")

	set(BUILD "${CMAKE_CURRENT_BINARY_DIR}/deppull/${STORAGE_PREFIX}/build")
	if(EXISTS "${BUILD}" AND "${ROOT}.ready" IS_NEWER_THAN "${BUILD}")
		file(REMOVE_RECURSE "${BUILD}")
	endif()

	if(EXISTS "${SRC}/CMakeLists.txt")
		add_subdirectory("${SRC}" "${BUILD}")
	endif()

	set(DEPPULL_${A_NAME}_ROOT "${ROOT}" PARENT_SCOPE)
	set(DEPPULL_${A_NAME}_SRC "${SRC}" PARENT_SCOPE)
	set(DEPPULL_${A_NAME}_BUILD "${BUILD}" PARENT_SCOPE)
endfunction()
