cmake_minimum_required(VERSION 3.0 FATAL_ERROR)

if(DEFINED _DEFAULT_DEPU_CACHE)
	return()
endif()

set(_DEFAULT_DEPU_CACHE "${CMAKE_SOURCE_DIR}/.depu")

if(NOT DEFINED DEPU_DL)
	if(DEFINED CACHE{DEPU_DL})
		set(DEPU_DL "$CACHE{DEPU_DL}")
	elseif(DEFINED ENV{DEPU_DL})
		set(DEPU_DL "$ENV{DEPU_DL}")
	else()
		set(DEPU_DL "${_DEFAULT_DEPU_CACHE}")
	endif()
endif()

string(TOUPPER "${DEPU_DL}" _DEPU_PATH_TOUPPER)

if("${_DEPU_PATH_TOUPPER}" STREQUAL "IN_HOME")
	if(WIN32)
		set(DEPU_DL "$ENV{USERPROFILE}/.depu")
	elseif(UNIX)
		set(DEPU_DL "$ENV{HOME}/.depu")
	endif()
elseif("${_DEPU_PATH_TOUPPER}" STREQUAL "IN_TEMP")
	if(WIN32)
		set(DEPU_DL "$ENV{TEMP}/.depu")
	elseif(UNIX)
		set(DEPU_DL "/tmp/.depu")
	endif()
endif()

file(TO_CMAKE_PATH "${DEPU_DL}" DEPU_DL)

message(STATUS "Depu: DEPU_DL = ${DEPU_DL}")

if(NOT DEFINED DEPU_DEV)
	if(DEFINED CACHE{DEPU_DEV})
		set(DEPU_DEV "$CACHE{DEPU_DEV}")
	elseif(DEFINED ENV{DEPU_DEV})
		set(DEPU_DEV "$ENV{DEPU_DEV}")
	else()
		set(DEPU_DEV "")
	endif()
endif()

if(DEPU_DEV)
	file(TO_CMAKE_PATH "${DEPU_DEV}" DEPU_DEV)
	message(STATUS "Depu: DEPU_DEV = ${DEPU_DEV}")
endif()

function(_depu_mkpaths A_STORAGE_PREFIX A_SRC_FIX)
	set(ROOT_REL "${A_STORAGE_PREFIX}/src")
	set(ROOT_REL "${ROOT_REL}" PARENT_SCOPE)

	set(ROOT "${DEPU_DL}/${ROOT_REL}")
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

function(depu A_NAME)
	if(DEFINED DEPU_${A_NAME}_ROOT)
		return()
	endif()

	message(STATUS "Depu: Checking '${A_NAME}' ...")

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

	if(DEPU_DEV)
		set(SRC "${DEPU_DEV}/${A_NAME}")
		if(EXISTS "${SRC}")
			set(STORAGE_PREFIX "${NAME_TOLOWER}/dev")
			set(FOUND TRUE)
		else()
			set(SRC "${DEPU_DEV}/${NAME_TOLOWER}")
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
				message(STATUS "Depu: Found '${A_NAME}@${${A_NAME}_VERSION}'")
				return()
			endif()
			message(STATUS "Depu: Found '${A_NAME}'")
			return()
		endif()
	endif()

	if(NOT FOUND AND A_PKG_URL)
		string(MAKE_C_IDENTIFIER "${A_PKG_HASH}" PKG_NAME)
		set(STORAGE_PREFIX "${NAME_TOLOWER}/${PKG_NAME}")

		_depu_mkpaths("${STORAGE_PREFIX}" "${A_SRC_FIX}")

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

		_depu_mkpaths("${STORAGE_PREFIX}" "${A_SRC_FIX}")

		if(NOT EXISTS "${ROOT}.ready")

			if(NOT DEFINED GIT_EXECUTABLE)
				find_package(Git REQUIRED QUIET)
			endif()

			if(NOT EXISTS "${DEPU_DL}")
				file(MAKE_DIRECTORY "${DEPU_DL}")
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
		message(FATAL_ERROR "Depu: Not found '${A_NAME}'")
	endif()

	message(STATUS "Depu: Using '${A_NAME}' at ${SRC}")

	set(BUILD "${CMAKE_CURRENT_BINARY_DIR}/depu/${STORAGE_PREFIX}/build")
	if(EXISTS "${BUILD}" AND "${ROOT}.ready" IS_NEWER_THAN "${BUILD}")
		file(REMOVE_RECURSE "${BUILD}")
	endif()

	if(EXISTS "${SRC}/CMakeLists.txt")
		add_subdirectory("${SRC}" "${BUILD}")
	endif()

	set(DEPU_${A_NAME}_ROOT "${ROOT}" PARENT_SCOPE)
	set(DEPU_${A_NAME}_SRC "${SRC}" PARENT_SCOPE)
	set(DEPU_${A_NAME}_BUILD "${BUILD}" PARENT_SCOPE)
endfunction()
