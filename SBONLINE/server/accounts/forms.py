from django import forms

from .models import (
    PLAYER_SESSION_LIMIT_MINUTES_MAX,
    PLAYER_SESSION_LIMIT_MINUTES_MIN,
    THEME_PREFERENCES,
    MemberProfile,
    SiteSettings,
)


class EnrollmentForm(forms.Form):
    invitation_code = forms.CharField(max_length=64, label="One-time invitation code", strip=True)

    def clean_invitation_code(self):
        return self.cleaned_data["invitation_code"].strip().upper()


class MemberProfileForm(forms.Form):
    display_name = forms.CharField(
        max_length=40,
        label="Display name",
        widget=forms.TextInput(attrs={"autocomplete": "nickname", "maxlength": 40}),
    )
    theme_preference = forms.ChoiceField(
        required=True,
        choices=THEME_PREFERENCES,
        label="Appearance",
    )

    def __init__(self, *args, user, **kwargs):
        self.user = user
        super().__init__(*args, **kwargs)

    def clean_display_name(self):
        display_name = " ".join(self.cleaned_data["display_name"].split())
        if not display_name:
            raise forms.ValidationError("Enter a display name.")
        profiles = MemberProfile.objects.filter(
            display_name__iexact=display_name,
        ).exclude(user=self.user)
        if profiles.exists():
            raise forms.ValidationError("That display name is already in use.")
        return display_name


class SiteSettingsForm(forms.ModelForm):
    player_session_limit_minutes = forms.IntegerField(
        min_value=PLAYER_SESSION_LIMIT_MINUTES_MIN,
        max_value=PLAYER_SESSION_LIMIT_MINUTES_MAX,
        widget=forms.NumberInput(attrs={
            "min": PLAYER_SESSION_LIMIT_MINUTES_MIN,
            "max": PLAYER_SESSION_LIMIT_MINUTES_MAX,
            "step": 1,
            "inputmode": "numeric",
        }),
        label="Playback session limit (minutes)",
    )

    class Meta:
        model = SiteSettings
        fields = ["aac_bitrate", "player_session_limit_minutes"]
        labels = {"aac_bitrate": "Global AAC bitrate"}
