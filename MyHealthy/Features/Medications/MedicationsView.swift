import SwiftData
import SwiftUI

enum MedicationRoute: Hashable {
    case search
    case add(DrugSearchResult)
    case manual(String)
    case existing(Medication)
}

struct MedicationsView: View {
    let profile: Profile
    @State private var path: [MedicationRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 14) {
                    Text("\(profile.displayName) · \(profile.activeMedications.count) active".uppercased())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    NavigationLink(value: MedicationRoute.search) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            Text("Search to add a medication")
                            Spacer()
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Palette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if profile.activeMedications.isEmpty {
                        Card {
                            EmptyStateView(
                                systemImage: "pills",
                                title: "No medications yet",
                                message: "Search by name to add a medication. The app fills in what it’s for and typical doses, and reminds \(profile.displayName) when it’s time."
                            )
                        }
                    } else {
                        weekCard
                        activeList
                    }

                    if !profile.pastMedications.isEmpty {
                        pastList
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle("Medications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: MedicationRoute.search) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add medication")
                }
            }
            .navigationDestination(for: MedicationRoute.self) { route in
                switch route {
                case .search:
                    MedicationSearchView(profile: profile)
                case .add(let result):
                    MedicationInfoView(mode: .add(result), profile: profile) { path.removeAll() }
                case .manual(let name):
                    MedicationInfoView(mode: .manual(name), profile: profile) { path.removeAll() }
                case .existing(let medication):
                    MedicationInfoView(mode: .existing(medication), profile: profile) { path.removeAll() }
                }
            }
        }
    }

    // MARK: Last 7 days

    private var weekCard: some View {
        let summary = profile.adherence(from: TrendRange.week.startDate())
        return Card(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 days")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(summary.taken) of \(summary.due) doses taken")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(summary.days) { day in
                    DayDoseBadge(day: day)
                        .frame(maxWidth: .infinity)
                }
            }
            if let insight = summary.insight {
                Text(insight)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activeList: some View {
        VStack(spacing: 6) {
            SectionHeader(title: "Active")
            VStack(spacing: 0) {
                ForEach(Array(profile.activeMedications.enumerated()), id: \.element.id) { index, medication in
                    if index > 0 {
                        Divider().padding(.leading, 72)
                    }
                    NavigationLink(value: MedicationRoute.existing(medication)) {
                        MedicationRow(medication: medication)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        }
    }

    private var pastList: some View {
        VStack(spacing: 6) {
            SectionHeader(title: "Past")
            VStack(spacing: 0) {
                ForEach(Array(profile.pastMedications.enumerated()), id: \.element.id) { index, medication in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    NavigationLink(value: MedicationRoute.existing(medication)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(medication.displayName)
                                    .foregroundStyle(.secondary)
                                if let stopped = medication.stoppedAt {
                                    Text("Stopped \(stopped.formatted(.dateTime.month(.wide).year()))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.chevron)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 60)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        }
    }
}

struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        HStack(spacing: 12) {
            MedicationTile(purpose: medication.purpose)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(medication.name)
                        .font(.body.weight(.semibold))
                    if !medication.strength.isEmpty {
                        Text(medication.strength)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(medication.scheduleText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !medication.purpose.isEmpty {
                    Text("For \(medication.purpose.lowercased())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let pills = medication.pillsLeft {
                Text(medication.needsRefill ? "\(pills) left · Refill" : "\(pills) left")
                    .font(.footnote.weight(medication.needsRefill ? .semibold : .regular))
                    .foregroundStyle(medication.needsRefill ? Palette.warn : .secondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.chevron)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 76)
        .contentShape(Rectangle())
    }
}

/// One day's dose status: filled check (all taken), orange ring (missed), dashed ring (today, pending).
struct DayDoseBadge: View {
    let day: DayAdherence

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                switch day.status {
                case .complete:
                    Circle().fill(Palette.fill)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                case .missed:
                    Circle().strokeBorder(Palette.diastolic, lineWidth: 2)
                    Text("\(day.taken)/\(day.expected)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.warn)
                case .pending:
                    Circle().strokeBorder(Color(uiColor: .tertiaryLabel), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    Text("\(day.taken)/\(day.expected)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                case .noDoses:
                    Circle().strokeBorder(Palette.separator, lineWidth: 1)
                }
            }
            .frame(width: 34, height: 34)
            Text(day.day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption)
                .fontWeight(Calendar.current.isDateInToday(day.day) ? .bold : .regular)
                .foregroundStyle(Calendar.current.isDateInToday(day.day) ? .primary : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let name = day.day.formatted(.dateTime.weekday(.wide))
        switch day.status {
        case .complete: return "\(name): all doses taken"
        case .missed: return "\(name): \(day.taken) of \(day.expected) doses taken"
        case .pending: return "\(name): \(day.taken) of \(day.expected) doses taken so far"
        case .noDoses: return "\(name): no doses scheduled"
        }
    }
}
