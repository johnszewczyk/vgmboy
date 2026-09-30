# Set Profiles

Set profiles define collection identity and source provenance. Apply the
[Base Set Profile](BASE-SET-PROFILE.md) together with the procedure for each
member's source format. Format procedures define which native fields are
recognized and how selected facts map to UAC.

## Profile Template and Profiles

Copy [`SET-PROFILE-TEMPLATE.md`](SET-PROFILE-TEMPLATE.md) when adding a set
profile. Keep the same headings and use concise `- **Topic** — rule` entries;
put source-field mappings in format profiles.

- **Shared rules** — [`BASE-SET-PROFILE.md`](BASE-SET-PROFILE.md) defines
  source authority, provenance, two-pass harvesting, and unresolved identity.
- **SNESMusic.org** — [`SNESMusicOrg.md`](SNESMusicOrg.md) records source
  linkage, RSN/SPC hash scopes, and identity enrichment.
- **Project 2612** — [`Project2612.md`](Project2612.md) records source package
  layout and set-specific checks.
