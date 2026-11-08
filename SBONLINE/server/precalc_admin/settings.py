import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured


BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY")
if not SECRET_KEY:
    raise ImproperlyConfigured("DJANGO_SECRET_KEY must be set outside the source tree.")

DEBUG = False
ALLOWED_HOSTS = ["admin.pre-calc.com"]
CSRF_TRUSTED_ORIGINS = ["https://admin.pre-calc.com"]

INSTALLED_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "accounts.apps.AccountsConfig",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "accounts.usage.PrivateUsageMiddleware",
    "accounts.middleware.LoginAuditMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "precalc_admin.urls"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [BASE_DIR / "templates"],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
        "accounts.context_processors.player_chrome",
    ]},
}]
WSGI_APPLICATION = "precalc_admin.wsgi.application"

DATABASES = {"default": {
    "ENGINE": "django.db.backends.sqlite3",
    "NAME": os.environ.get("DJANGO_DB_PATH", "/var/lib/precalc-admin/db.sqlite3"),
    "OPTIONS": {"timeout": 20},
}}

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.ScryptPasswordHasher",
]
AUTHENTICATION_BACKENDS = ["django.contrib.auth.backends.ModelBackend"]
LOGIN_URL = "/login/"
LOGIN_REDIRECT_URL = "/spcboy/"
LOGOUT_REDIRECT_URL = "/login/"

LANGUAGE_CODE = "en-us"
TIME_ZONE = "America/Detroit"
USE_I18N = True
USE_TZ = True
STATIC_URL = "/static/"
STATIC_ROOT = os.environ.get("DJANGO_STATIC_ROOT", "/var/www/precalc-admin-static")
STATICFILES_DIRS = [BASE_DIR / "static"]
SPCBOY_MEDIA_ROOT = Path(os.environ.get("SPCBOY_MEDIA_ROOT", "/var/lib/precalc-admin/media/spcboy"))
SPCBOY_GALLERY_CACHE_ROOT = Path(os.environ.get(
    "SPCBOY_GALLERY_CACHE_ROOT",
    str(SPCBOY_MEDIA_ROOT / "gallery-cache"),
))
SPCBOY_SEARCH_INDEX_PATH = Path(os.environ.get(
    "SPCBOY_SEARCH_INDEX_PATH",
    str(Path(os.environ.get("DJANGO_DB_PATH", "/var/lib/precalc-admin/db.sqlite3")).parent / "spcboy-search.sqlite3"),
))
COMMUNITY_MEDIA_ROOT = Path(os.environ.get("COMMUNITY_MEDIA_ROOT", "/var/lib/precalc-admin/media/community"))
MEDIA_ROOT = COMMUNITY_MEDIA_ROOT
MEDIA_URL = "/community-media/"
DATA_UPLOAD_MAX_MEMORY_SIZE = 4 * 1024 * 1024
PRIVATE_BACKUP_STATUS_PATH = Path(os.environ.get(
    "PRIVATE_BACKUP_STATUS_PATH",
    "/var/lib/precalc-admin/backup-status/status.json",
))
SPCBOY_STREAMER = Path(os.environ.get("SPCBOY_STREAMER", BASE_DIR / "streaming/build/bin/spcboy-stream"))
SPCBOY_PREPARE_EXECUTABLE = Path(os.environ.get(
    "SPCBOY_PREPARE_EXECUTABLE",
    "/opt/precalc-admin/bin/vgmboy-prepare",
))
SPCBOY_FFMPEG = os.environ.get("SPCBOY_FFMPEG", "/usr/bin/ffmpeg")
SPCBOY_7Z = os.environ.get("SPCBOY_7Z", "/usr/bin/7z")
SPCBOY_ZSTD = os.environ.get("SPCBOY_ZSTD", "/usr/bin/zstd")
SPCBOY_TAR = os.environ.get("SPCBOY_TAR", "/usr/bin/tar")
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

SESSION_COOKIE_AGE = 86_400
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_SAMESITE = "Lax"
SESSION_SAVE_EVERY_REQUEST = True
CSRF_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_SAMESITE = "Lax"

SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_HSTS_SECONDS = 31_536_000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = False
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
X_FRAME_OPTIONS = "DENY"
