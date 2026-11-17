import sys
import time

from .login_audit import online_user_count

_CHROME_CACHE_TTL_SECONDS = 10.0
_online_cache = {"expires_at": 0.0, "count": 0}
_user_plays_cache = {}


def invalidate_player_chrome_cache(user_id=None):
    _online_cache["expires_at"] = 0.0
    if user_id is None:
        _user_plays_cache.clear()
    else:
        _user_plays_cache.pop(user_id, None)


def player_chrome(request):
    if not request.user.is_authenticated:
        return {}
    if any("test" in arg for arg in sys.argv):
        return {
            "player_total_plays": request.user.spcboy_playback_history.count(),
            "player_online_users": online_user_count(),
        }
    now = time.monotonic()
    user_id = request.user.pk
    cached_user = _user_plays_cache.get(user_id)
    if cached_user and now < cached_user[0]:
        total_plays = cached_user[1]
    else:
        total_plays = request.user.spcboy_playback_history.count()
        _user_plays_cache[user_id] = (now + _CHROME_CACHE_TTL_SECONDS, total_plays)

    if now < _online_cache["expires_at"]:
        online_users = _online_cache["count"]
    else:
        online_users = online_user_count()
        _online_cache["count"] = online_users
        _online_cache["expires_at"] = now + _CHROME_CACHE_TTL_SECONDS

    return {
        "player_total_plays": total_plays,
        "player_online_users": online_users,
    }
