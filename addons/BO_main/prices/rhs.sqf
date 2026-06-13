/*
 * RHS price pack — curated baseline prices for the Red Hammer Studios
 * mod families (AFRF, USAF, GREF, SAF). Loaded by BO_fnc_loadPricePack
 * at init when RHS is detected in the loaded addon set.
 *
 * Format: [classname, [base, wood, steel, plastic]]
 *
 * This is a STARTER LIST — expand based on real-world use. Items not
 * listed fall through to the layered resolver (magazine compatibility
 * → faction average → heuristic with clamps), which produces sensible
 * values for most items but won't match curated balance exactly.
 *
 * Community contributions welcome: publish your own @BO_Prices_<mod>
 * addon with a similar structure.
 */

[
    // ----- RHS AFRF rifles -----
    ["rhs_weap_ak74m",        [1300, 0, 2, 0]],
    ["rhs_weap_ak74m_gp25",   [1600, 0, 2, 0]],
    ["rhs_weap_ak103",        [1500, 0, 2, 0]],
    ["rhs_weap_ak103_zenitco01_b33", [1800, 0, 2, 0]],
    ["rhs_weap_aks74",        [1100, 0, 2, 0]],
    ["rhs_weap_aks74u",       [800,  0, 1, 0]],
    ["rhs_weap_pkm",          [1800, 0, 3, 0]],
    ["rhs_weap_pkp",          [1900, 0, 3, 0]],
    ["rhs_weap_svd",          [2400, 0, 3, 0]],
    ["rhs_weap_svdp",         [2600, 0, 3, 0]],
    ["rhs_weap_makarov_pm",   [200,  0, 1, 0]],
    ["rhs_weap_pya",          [350,  0, 1, 0]],
    ["rhs_weap_rpg7",         [1200, 0, 2, 1]],
    ["rhs_weap_rshg2",        [1100, 0, 2, 1]],

    // ----- RHS USAF rifles -----
    ["rhs_weap_m4",                  [1400, 0, 2, 0]],
    ["rhs_weap_m4a1",                [1500, 0, 2, 0]],
    ["rhs_weap_m4a1_m203",           [1700, 0, 2, 0]],
    ["rhs_weap_m16a4_carryhandle",   [1300, 0, 2, 0]],
    ["rhs_weap_m249",                [1900, 0, 3, 0]],
    ["rhs_weap_m240B",                [2000, 0, 3, 0]],
    ["rhs_weap_m24sws",              [2800, 0, 3, 0]],
    ["rhs_weap_M107",                [4500, 0, 4, 0]],
    ["rhs_weap_M320",                [800,  0, 2, 0]],
    ["rhs_weap_m1911a1",             [250,  0, 1, 0]],

    // ----- Common RHS magazines -----
    ["rhs_30Rnd_545x39_7N10_AK",         [30, 0, 0.1, 0]],
    ["rhs_30Rnd_545x39_7N22_AK",         [35, 0, 0.1, 0]],
    ["rhs_30Rnd_762x39mm",               [40, 0, 0.1, 0]],
    ["rhs_mag_30Rnd_556x45_M855_Stanag", [25, 0, 0.1, 0]],
    ["rhs_mag_30Rnd_556x45_M855A1_Stanag",[30, 0, 0.1, 0]],
    ["rhs_100Rnd_762x51_M80_Belt",       [120, 0, 0.5, 0]],
    ["rhsusf_100Rnd_762x51",             [120, 0, 0.5, 0]],
    ["rhs_100Rnd_762x54mmR_7N1",         [100, 0, 0.5, 0]],
    ["rhs_5Rnd_762x54_762B_SVD",         [80,  0, 0.3, 0]],
    ["rhs_mag_8Rnd_9x18_57N181S",        [12,  0, 0.1, 0]],
    ["rhs_mag_7Rnd_45acp_MHP",           [15,  0, 0.1, 0]],

    // ----- RHS vests / helmets (representative) -----
    ["rhs_6b13_Flora_6sh92_radio",  [400, 0, 4, 0]],
    ["rhs_6b27m_ess_bala",          [180, 0, 2, 0]],
    ["rhsusf_iotv_ucp",             [600, 0, 5, 0]],
    ["rhsusf_iotv_ocp",             [600, 0, 5, 0]],
    ["rhsusf_ach_helmet_ucp",       [250, 0, 3, 0]],

    // ----- RHS vehicles (representative tier sample) -----
    ["rhs_uaz_open_chdkz",            [3500,  0, 50,  3]],
    ["rhs_btr60_msv",                 [40000, 0, 200, 8]],
    ["rhs_btr70_msv",                 [55000, 0, 240, 8]],
    ["rhs_btr80_msv",                 [70000, 0, 280, 10]],
    ["rhsusf_m1025_w_m2",             [25000, 0, 100, 5]],
    ["rhsusf_M1230a1_usarmy_wd",      [80000, 0, 300, 12]],
    ["rhs_t72bb_tv",                  [350000, 0, 800, 30]],
    ["rhs_m1a1aimd_usarmy",           [400000, 0, 850, 35]]
]
