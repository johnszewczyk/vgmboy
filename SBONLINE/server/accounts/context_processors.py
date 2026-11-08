from .login_audit import online_user_count


def player_chrome(request):
    if not request.user.is_authenticated:
        return {}
    return {
        "player_total_plays": request.user.spcboy_playback_history.count(),
        "player_online_users": online_user_count(),
    }
