#ifndef _RUA_MINHOOK_HPP
#define _RUA_MINHOOK_HPP

#include <MinHook.h>

#include <mutex>
#include <cassert>

namespace _minhook_cpp {
	extern size_t count;
	extern std::mutex mtx;
}

template <typename T>
class minhook {
	public:
		using target_type = T;

		constexpr minhook() : _t(nullptr), _o(nullptr) {}

		minhook(T target, T detour) : _t(nullptr) {
			install(target, detour);
		}

		minhook(const minhook<T> &) = delete;

		minhook<T> &operator=(const minhook<T> &) = delete;

		minhook(minhook<T> &&src) : _t(src._t), _o(src._o) {
			if (src._t) {
				src._t = nullptr;
				src._o = nullptr;
			}
		}

		minhook<T> &operator=(minhook<T> &&src) {
			uninstall();

			if (src._t) {
				_t = src._t;
				_o = src._o;

				src._t = nullptr;
				src._o = nullptr;
			}

			return *this;
		}

		~minhook() {
			uninstall();
		}

		bool install(T target, T detour) {
			uninstall();

			_minhook_cpp::mtx.lock();

			if (!_minhook_cpp::count) {
				if (MH_Initialize() == MH_ERROR_MEMORY_ALLOC) {
					return false;
				}
			}

			if (MH_CreateHook(reinterpret_cast<LPVOID>(target), reinterpret_cast<LPVOID>(detour), reinterpret_cast<LPVOID *>(&_o)) != MH_OK) {
				if (!_minhook_cpp::count) {
					MH_Uninitialize();
				}
				return false;
			}

			if (MH_EnableHook(reinterpret_cast<LPVOID>(target)) != MH_OK) {
				if (!_minhook_cpp::count) {
					MH_Uninitialize();
				}
				return false;
			}

			++_minhook_cpp::count;

			_minhook_cpp::mtx.unlock();

			_t = target;
			return true;
		}

		operator bool() const {
			return _t;
		}

		template <typename... A>
		auto original(A&&... a) const -> decltype((*reinterpret_cast<T>(0))(std::forward<A>(a)...)) {
			assert(_o);

			return _o(std::forward<A>(a)...);
		}

		void uninstall() {
			if (_t) {
				MH_DisableHook(reinterpret_cast<LPVOID>(_t));
				MH_RemoveHook(reinterpret_cast<LPVOID>(_t));
				_t = nullptr;
				_o = nullptr;

				_minhook_cpp::mtx.lock();
				if (!--_minhook_cpp::count) {
					MH_Uninitialize();
				}
				_minhook_cpp::mtx.unlock();
			}
		}

	private:
		T _t, _o;
};

#endif
