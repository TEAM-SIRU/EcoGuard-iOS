import SwiftUI

/// Figma `Recent section` (258:2). 최근 청소 기록 3건.
struct HomeRecentRecordsSection: View {
    let records: [CleaningRecord]
    let onOpenAll: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("최근 청소 기록")
                    .ecoFont(.title4)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onOpenAll) {
                    Text("전체보기")
                        .ecoFont(.subMedium)
                        .foregroundStyle(Color.ecoTextCaption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.xs)
            ForEach(records) { record in
                HomeRecordRow(record: record)
            }
        }
        .padding(.top, Spacing.md)
    }
}

/// Figma `Record card` (258:6).
private struct HomeRecordRow: View {
    let record: CleaningRecord

    var body: some View {
        EcoCard(.row) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(record.cleanedAt.map { HomeFormatter.recordDate($0) } ?? ActivityRecordsFormatter.recordDate(record.date))
                        .ecoFont(.title5)
                        .foregroundStyle(Color.ecoTextPrimary)
                    Text(record.area)
                        .ecoFont(.sub)
                        .foregroundStyle(Color.ecoTextCaption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    StatusChip(status: chipStatus)
                    if let minutes {
                        Text(minutes)
                            .ecoFont(.captionMedium)
                            .foregroundStyle(minutesColor)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chipStatus: StatusChip.Status {
        switch record.result {
        case .approved: .approved
        case .rejected: .rejected
        case .processing: .processing
        }
    }

    private var minutes: String? {
        switch record.result {
        case .approved(let earnedMinutes): String(localized: "+\(earnedMinutes)분")
        case .rejected: String(localized: "0분")
        case .processing: nil
        }
    }

    private var minutesColor: Color {
        switch record.result {
        case .approved: .ecoTextSub
        case .rejected, .processing: .ecoDisabled
        }
    }
}
