import Foundation

/// A small built-in library of common blood pressure and cholesterol medications,
/// written in plain language. Used offline and ranked first in search results.
/// General reference only — the dose on a person's prescription label always wins.
enum MedicationLibrary {
    static func medlinePlusSearchURL(_ name: String) -> String {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return "https://vsearch.nlm.nih.gov/vivisimo/cgi-bin/query-meta?v%3Aproject=medlineplus&v%3Asources=medlineplus-bundle&query=\(query)"
    }

    static let aceWarning = "Get medical help right away for swelling of the face, lips, tongue or throat, or trouble breathing or swallowing."
    static let statinWarning = "Call your doctor right away for unexplained muscle pain, tenderness or weakness — especially with fever or dark urine."

    static let all: [DrugInfo] = [
        DrugInfo(
            name: "Amlodipine",
            brandNames: ["Norvasc"],
            drugClass: "Calcium channel blocker",
            purpose: "Blood pressure",
            whatItsFor: "Lowers high blood pressure. Also used to prevent some kinds of chest pain (angina).",
            howItWorks: "Relaxes and widens blood vessels, so blood flows more easily and the heart doesn’t have to pump as hard.",
            doseLines: [
                DoseLine(label: "Usual starting dose", value: "5 mg once a day"),
                DoseLine(label: "Maximum", value: "10 mg once a day"),
                DoseLine(label: "Older adults or liver problems", value: "Often 2.5 mg to start")
            ],
            howToTake: ["Once a day, around the same time.", "With or without food.", DrugText.missedDose],
            commonSideEffects: ["Swollen ankles or feet", "Flushing", "Headache", "Dizziness", "Tiredness"],
            urgentWarning: "Get medical help right away for chest pain that is new or worse, fainting, or a fast or pounding heartbeat.",
            strengths: ["2.5 mg", "5 mg", "10 mg"],
            form: "tablet",
            sourceName: "MedlinePlus",
            sourceURL: "https://medlineplus.gov/druginfo/meds/a692044.html",
            isCurated: true
        ),
        DrugInfo(
            name: "Ramipril",
            brandNames: ["Altace"],
            drugClass: "ACE inhibitor",
            purpose: "Blood pressure",
            whatItsFor: "Lowers high blood pressure. Also used to lower the risk of heart attack and stroke in some people, and after a heart attack.",
            howItWorks: "Blocks an enzyme the body uses to make angiotensin, a hormone that narrows blood vessels. Vessels relax and pressure goes down.",
            doseLines: [
                DoseLine(label: "Usual starting dose", value: "2.5 mg once a day"),
                DoseLine(label: "Usual range", value: "2.5–20 mg a day, once or split in two"),
                DoseLine(label: "Maximum", value: "20 mg a day")
            ],
            howToTake: [
                "At the same time each day, with or without food.",
                "Ask before using potassium supplements or salt substitutes.",
                DrugText.missedDose
            ],
            commonSideEffects: ["Dry cough", "Dizziness", "Tiredness", "Headache"],
            urgentWarning: aceWarning,
            strengths: ["1.25 mg", "2.5 mg", "5 mg", "10 mg"],
            form: "capsule",
            sourceName: "MedlinePlus",
            sourceURL: medlinePlusSearchURL("ramipril"),
            isCurated: true
        ),
        DrugInfo(
            name: "Lisinopril",
            brandNames: ["Zestril", "Prinivil"],
            drugClass: "ACE inhibitor",
            purpose: "Blood pressure",
            whatItsFor: "Lowers high blood pressure. Also used for heart failure and after a heart attack.",
            howItWorks: "Blocks an enzyme the body uses to make angiotensin, a hormone that narrows blood vessels. Vessels relax and pressure goes down.",
            doseLines: [
                DoseLine(label: "Usual starting dose", value: "10 mg once a day (5 mg if also on a water pill)"),
                DoseLine(label: "Usual range", value: "20–40 mg once a day"),
                DoseLine(label: "Maximum", value: "80 mg a day")
            ],
            howToTake: [
                "Once a day, at the same time, with or without food.",
                "Ask before using potassium supplements or salt substitutes.",
                DrugText.missedDose
            ],
            commonSideEffects: ["Dry cough", "Dizziness", "Headache", "Tiredness"],
            urgentWarning: aceWarning,
            strengths: ["5 mg", "10 mg", "20 mg"],
            form: "tablet",
            sourceName: "MedlinePlus",
            sourceURL: medlinePlusSearchURL("lisinopril"),
            isCurated: true
        ),
        DrugInfo(
            name: "Losartan",
            brandNames: ["Cozaar"],
            drugClass: "Angiotensin receptor blocker (ARB)",
            purpose: "Blood pressure",
            whatItsFor: "Lowers high blood pressure. Also used to protect the kidneys in some people with type 2 diabetes.",
            howItWorks: "Blocks the action of angiotensin, a hormone that narrows blood vessels, so vessels relax and pressure goes down.",
            doseLines: [
                DoseLine(label: "Usual starting dose", value: "50 mg once a day"),
                DoseLine(label: "Maximum", value: "100 mg a day, once or split in two"),
                DoseLine(label: "Liver problems or low fluid levels", value: "Often 25 mg to start")
            ],
            howToTake: ["Once a day, at the same time, with or without food.", DrugText.missedDose],
            commonSideEffects: ["Dizziness", "Stuffy nose", "Back or leg pain", "Tiredness"],
            urgentWarning: aceWarning,
            strengths: ["25 mg", "50 mg", "100 mg"],
            form: "tablet",
            sourceName: "MedlinePlus",
            sourceURL: medlinePlusSearchURL("losartan"),
            isCurated: true
        ),
        DrugInfo(
            name: "Hydrochlorothiazide",
            brandNames: ["Microzide"],
            drugClass: "Thiazide diuretic (water pill)",
            purpose: "Blood pressure",
            whatItsFor: "Lowers high blood pressure and reduces fluid build-up (swelling).",
            howItWorks: "Helps the kidneys remove extra salt and water, which lowers the amount of fluid in the blood vessels.",
            doseLines: [
                DoseLine(label: "Usual starting dose", value: "12.5–25 mg once a day"),
                DoseLine(label: "Maximum (blood pressure)", value: "50 mg a day")
            ],
            howToTake: [
                "Take it in the morning so you’re not up at night to urinate.",
                "With or without food.",
                DrugText.missedDose
            ],
            commonSideEffects: ["Urinating more often", "Dizziness when standing up", "Muscle cramps", "Sensitivity to sunlight"],
            urgentWarning: "Get medical help for fainting, extreme thirst with a very dry mouth, or sudden eye pain or blurred vision.",
            strengths: ["12.5 mg", "25 mg", "50 mg"],
            form: "tablet",
            sourceName: "MedlinePlus",
            sourceURL: medlinePlusSearchURL("hydrochlorothiazide"),
            isCurated: true
        ),
        DrugInfo(
            name: "Rosuvastatin",
            brandNames: ["Crestor"],
            drugClass: "Statin",
            purpose: "Cholesterol",
            whatItsFor: "Lowers LDL (“bad”) cholesterol and triglycerides, and lowers the risk of heart attack and stroke.",
            howItWorks: "Blocks an enzyme the liver uses to make cholesterol.",
            doseLines: [
                DoseLine(label: "Usual starting dose", value: "10 mg once a day"),
                DoseLine(label: "Range", value: "5–40 mg once a day"),
                DoseLine(label: "People of Asian descent", value: "Often 5 mg to start")
            ],
            howToTake: ["Once a day, at any time — keep it consistent.", "With or without food.", DrugText.missedDose],
            commonSideEffects: ["Muscle aches", "Headache", "Stomach pain", "Nausea"],
            urgentWarning: statinWarning,
            strengths: ["5 mg", "10 mg", "20 mg", "40 mg"],
            form: "tablet",
            sourceName: "MedlinePlus",
            sourceURL: medlinePlusSearchURL("rosuvastatin"),
            isCurated: true
        ),
        DrugInfo(
            name: "Atorvastatin",
            brandNames: ["Lipitor"],
            drugClass: "Statin",
            purpose: "Cholesterol",
            whatItsFor: "Lowers LDL (“bad”) cholesterol and triglycerides, and lowers the risk of heart attack and stroke.",
            howItWorks: "Blocks an enzyme the liver uses to make cholesterol.",
            doseLines: [
                DoseLine(label: "Usual starting dose", value: "10–20 mg once a day"),
                DoseLine(label: "Range", value: "10–80 mg once a day")
            ],
            howToTake: ["Once a day, at any time — keep it consistent.", "With or without food.", DrugText.missedDose],
            commonSideEffects: ["Muscle or joint pain", "Diarrhea", "Stuffy nose", "Upset stomach"],
            urgentWarning: statinWarning,
            strengths: ["10 mg", "20 mg", "40 mg", "80 mg"],
            form: "tablet",
            sourceName: "MedlinePlus",
            sourceURL: medlinePlusSearchURL("atorvastatin"),
            isCurated: true
        )
    ]

    /// Library matches for a search term, best first (name prefix, brand prefix, then contains).
    static func search(_ term: String) -> [DrugInfo] {
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= 2 else { return [] }
        func score(_ info: DrugInfo) -> Int? {
            let name = info.name.lowercased()
            let brands = info.brandNames.map { $0.lowercased() }
            if name.hasPrefix(query) { return 0 }
            if brands.contains(where: { $0.hasPrefix(query) }) { return 1 }
            if name.contains(query) { return 2 }
            if brands.contains(where: { $0.contains(query) }) { return 3 }
            return nil
        }
        return all
            .compactMap { info in score(info).map { (info, $0) } }
            .sorted { $0.1 == $1.1 ? $0.0.name < $1.0.name : $0.1 < $1.1 }
            .map { $0.0 }
    }

    static func lookup(name: String) -> DrugInfo? {
        let key = name.lowercased()
        return all.first { $0.name.lowercased() == key }
    }
}
