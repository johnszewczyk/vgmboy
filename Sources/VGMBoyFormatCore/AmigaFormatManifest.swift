import Foundation

/// Filename prefixes used by UADE's Amiga EaglePlayer registry.
///
/// Amiga music commonly predates filename suffix conventions. A member such
/// as `mod.title` or `p4x.stage` identifies its replayer from the prefix, not
/// from the string after the final dot. Keep this manifest in the shared
/// format-core product so ScanSong and VGMBoy make the same admission
/// decision without depending on either frontend.
public enum AmigaFormatManifest {
    public static let prefixes: Set<String> = Set("""
        !pm!, 1gu, 1pj, 2gu, 2pj, 3gu, 3octstr, 3pj, 4gu, 4pj, 5gu, 5pj, 5thaugrel,
        5thaugstr, 6gu, 6pj, 7gu, 7pj, 7thdimstr, 8gu, 8pj, 9pj, 40a, 40b, 41a,
        50a, 60a, 61a, aa, abk, absoftbase1, absoftbase2, ac1, ac1d, adpcm, adsc, ae,
        agi, ahx, alp, amc, aon, aon4, aon8, aps, arp, ash, ast, aval, avp, aam, bfc,
        bds, bd, bfc, bsi, bp, bp3, br, bss, bye, chan, cin, cm, core, cplx, cp, crb, cus,
        cust, custom, cw, dat, db, dh, digi, di, dm, dm1, dm2, dl, dl_deli, dlm1, dlm2, dln,
        dmu, dmu2, dns, doda, dp, dsr, dsc, dss, dum, dw, dwold, dz, ea, emod, ems, emsv6, eu, ex,
        fc, fc3, fc4, fc13, fc14, fc-bsi, fc-m, fcm, flt4, fred, fp, ft, fuz, fuzz, fw, glue,
        gm, gmc, gray, gv, hd, hip, hip7, hipc, hmc, hn, hot, hrt, hrt!, hst, ice, ims, is,
        is20, it1, jam, jb, jc, jcb, jcbo, jd, jmf, jo, jp, jpn, jpo, jpnd, jpold, js, jt, kef,
        kef7, kh, kim, kris, krs, ksm, lax, lme, lion, ma, max, mc, mcmd, mcmd_org, mco, mcr, md, mdat,
        mdst, med, mexxmp, mfp, mg, midi, mk2, mkii, mkiio, ml, mm4, mm8, mmd0, mmd1, mmd2, mmdc, mms, mod,
        mod15, mod15_mst, mod15_st-iv, mod15_ust, mod3, mod_adsc4, mod_comp, mod_doc, mod_flt4, mod_ntk,
        mod_ntk1, mod_ntk2, mod_ntkamp, mon,
        mon_old, mok, mosh, mpro, mso, mtp2, mug, mug2, mus, mw, noisepacker2, noisepacker3, np, np1,
        np2, np3, nr, nru, ntp, ntpk, npp, octamed, okta, okt, one, osp, p10, p21, p30,
        p40a, p40b, p41a, p4x, p50a, p5a, p5x, p60, p60a, p61, p61a, p6x, pap,
        pat, pha, pin, pm, pm0, pm01, pm1, pm10c, pm18a, pm2, pm20, pm4, pm40, pmz,
        pn, polk, powt, pp10, pp20, pp21, pp30, ppk, pr1, pr2, prom, pru, pru1,
        pru2, prun, prun1, prun2, prt, pt, ptm, puma, pvp, ps, psa, psf, pwr, pyg, pygm, pygmy, qc, qpa,
        qts, qtx, rj, rjp, riff, rh, rho, rk, rkb, s-c, s7g, sas, sa, sa-p, sa_old, sb, sc,
        scn, scr, sct, scumm, sdata, sdr, sfx, sfx13, sfx20, sg, sid, sid1, sid2, sjs, skt, skyt, sm, sm1, sm2, sm3,
        smn, smpro, smod, smus, sndmon, sng, snk, snt, snt!, snx, sog, soc, sonic, spl, sqt, ss, st, st2,
        st26, st30, star, stpk, sun, syn, synmod, tcb, tf, tfhd1.5, tfhd7v, tfhdpro,
        tfmx, tfmx1.5, tfmx7v, tfmxpro, thm, thn, thx, tiny, tits, tmk, tme, tp, tp1, tp2,
        tp3, trc, tro, tronic, tpu, two, tw, ufo, uds, un2, unic, unic2, vss, wb, wn,
        xan, xann, ym, ymst, zen
        """
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
    )

    /// Returns the longest matching Amiga prefix for a complete path.
    /// Longest-match handling matters for entries such as `tfmx1.5`.
    public static func prefix(for path: String) -> String? {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return prefixes
            .sorted { $0.count > $1.count }
            .first { name == $0 || name.hasPrefix($0 + ".") }
    }
}
