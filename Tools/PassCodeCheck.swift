// Holds TallinnTasteBuds/Core/PassCode.swift to codes made by the website's
// own algorithm (assets/pass.js, reproduced in Node), so the app's QR can never
// drift from what verify.html accepts. CI compiles this beside PassCode.swift
// as main.swift and runs it:
//
//   cp Tools/PassCodeCheck.swift "$tmp/main.swift"
//   swiftc TallinnTasteBuds/Core/PassCode.swift "$tmp/main.swift" -o "$tmp/check" && "$tmp/check"
//
// The keys below are the ones in the website's data/deals.json (public by
// design) and the example key in its README.
import Foundation

let vectors: [(key: String, place: String, hour: Int, rate: Int?, code: String)] = [
    ("RH0WBQ494H7T37VGCF1W98CZ2A00FNJT", "pudel", 496000, nil, "8S94A"),
    ("RH0WBQ494H7T37VGCF1W98CZ2A00FNJT", "pudel", 496001, nil, "C72GA"),
    ("CXMXRR04BX83FF38VZTX3CAJTMTF7C5Z", "magussoolane", 497123, nil, "976N4"),
    ("PR3S960YQP1RZ4HR74H5ABSBBZ3XNMCV", "ChIJjT6uOdiVkkYRwHK_f2mL67M", 500000, 20, "5F9AF"),
    ("PR3S960YQP1RZ4HR74H5ABSBBZ3XNMCV", "bekker-pagariari", 499999, 5, "9EC0S"),
]

var failed = 0
for v in vectors {
    let got = PassCode.code(key: v.key, place: v.place, hour: v.hour, rate: v.rate)
    if got == v.code {
        print("ok: \(v.place) hour \(v.hour)\(v.rate.map { " rate \($0)" } ?? "") -> \(got)")
    } else {
        print("MISMATCH: \(v.place) hour \(v.hour): expected \(v.code), got \(got)")
        failed += 1
    }
}
let url = PassCode.verifyURL(base: URL(string: "https://tallinntastebuds.ee")!, place: "pudel", hour: 496000, code: "8S94A", rate: nil)
if url.absoluteString != "https://tallinntastebuds.ee/verify.html?r=pudel&h=496000&c=8S94A" {
    print("MISMATCH: verify URL \(url.absoluteString)")
    failed += 1
}
exit(failed == 0 ? 0 : 1)
