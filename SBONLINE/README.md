# SBONLINE

SBONLINE is VGMMan's hosted SPCBOY web player for the private
`admin.pre-calc.com` address. It is a separate browser product from SB2.

## Source and release

- `server/` contains the complete Django app: player UI, accounts, profiles,
  catalog adapters, and AAC streaming endpoint.
- `ops/server/` contains the webspace release, service setup, and recovery
  tooling. Deploy from the VGMMan repository with
  `bash SBONLINE/ops/server/sbonline-deploy.sh`.
- `prototypes/mobile/` is a sample-only design fixture. It is not connected to
  the hosted catalog, account, or playback services.

The rented webspace and its credentials are deployment targets. The SBO Nginx
virtual host, Django source, build, and release steps are owned here. MathBook
contains only its math site and its own virtual host. Persistent account state,
media, and credentials remain on the host and are never copied into Git.

Catalog publication remains with ScanSong. Playback admission, source
preparation, and decoder sources remain with VGMBoy.
