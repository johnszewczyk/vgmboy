from .login_audit import touch_login_session


class LoginAuditMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        touch_login_session(request)
        return response
