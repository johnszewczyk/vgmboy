# Private-site and droplet bandwidth reconciliation

## Snapshot

Collected from the Pre-Calc droplet on 2026-10-31 at about 16:41 UTC. vnStat
had last updated its monthly row at 16:40 UTC; the private usage rows were
updated through 16:40 UTC. Both the vnStat collector and private-admin service
were active. The vnStat interface database was created on 2026-10-07, so this
installation has no earlier droplet history.

The checks used `vnstat -i eth0 --json m 12` and a read-only aggregate of
`accounts_monthlyusage` for the UTC month `2026-10-01`. The database query
returned four account-month rows and no account identities.

## October totals so far

| Measurement | Bytes | Decimal units |
| --- | ---: | ---: |
| Droplet received (`eth0 rx`) | 5,993,534,349 | 5.994 GB |
| Droplet sent (`eth0 tx`) | 4,073,050,029 | 4.073 GB |
| Droplet received + sent | 10,066,584,378 | 10.067 GB |
| Authenticated private-site response bodies (`site_bytes`) | 391,088,582 | 0.391 GB |
| Authenticated media response bodies (`media_bytes`) | 2,778,362,432 | 2.778 GB |
| Account response total (`site_bytes + media_bytes`) | 3,169,451,014 | 3.169 GB |
| Separate AAC quota counter (`audio_bytes`) | 2,798,060,421 | 2.798 GB |

The private response total is about 77.8% of droplet `tx`. The remaining
outbound difference is about 904 MB (22.2%). This is a scale comparison, not
an exact reconciliation: Django counts authenticated response bodies, while
vnStat measures network-interface bytes.

The 2.798 GB AAC quota counter is separate from `media_bytes`; do not add it
again to the response total. It counts bytes claimed against each account's
streaming allowance before yielding chunks, while the middleware counts
response-body chunks.

## Validation and limits

The owner Usage chart uses the same `vnstat -i eth0 --json m 12` source and
sums `rx + tx`, so it should show approximately **10.067 GB** for October at this
snapshot. The account total is a separate private-app body-byte rollup. For
outbound comparison, use `tx` (4.073 GB), not the chart's `rx + tx` total.

The evidence confirms that signed-in SBO responses account for most of the
measured outbound scale. It does not isolate the public Math site: vnStat
collects the whole droplet, and its interface total is not split by website.
The residual may include public pages, Nginx-served static assets, anonymous
requests, and HTTP/TLS/network overhead. This check cannot prove that the
Math site contributes a negligible amount.

vnStat began collecting on October 7, and October was still in progress during
the snapshot. Provider billing can use a different accounting boundary.
