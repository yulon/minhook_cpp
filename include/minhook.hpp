#ifndef _MINHOOK_HPP
#define _MINHOOK_HPP

#include <MinHook.h>

#include <mutex>
#include <cassert>

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

			auto &s_ctx = _s_ctx();

			s_ctx.mtx.lock();

			if (!s_ctx.count) {
				if (MH_Initialize() == MH_ERROR_MEMORY_ALLOC) {
					return false;
				}
			}

			if (MH_CreateHook(reinterpret_cast<LPVOID>(target), reinterpret_cast<LPVOID>(detour), reinterpret_cast<LPVOID *>(&_o)) != MH_OK) {
				if (!s_ctx.count) {
					MH_Uninitialize();
				}
				return false;
			}

			if (MH_EnableHook(reinterpret_cast<LPVOID>(target)) != MH_OK) {
				if (!s_ctx.count) {
					MH_Uninitialize();
				}
				return false;
			}

			++s_ctx.count;

			s_ctx.mtx.unlock();

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

				auto &s_ctx = _s_ctx();
				s_ctx.mtx.lock();
				if (!--s_ctx.count) {
					MH_Uninitialize();
				}
				s_ctx.mtx.unlock();
			}
		}

	private:
		T _t, _o;

		struct _s_ctx_t {
			size_t count = 0;
			std::mutex mtx;
		};

		inline _s_ctx_t &_s_ctx() {
			static _s_ctx_t inst;
			return inst;
		}
};

#endif
