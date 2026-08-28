#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

path = ROOT / "Mira/App/MiraStore+Conversation.swift"
text = path.read_text(encoding="utf-8")
old = '''        let selected = draft.selectedRecommendations.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.timeBand.rawValue < $1.timeBand.rawValue
        }
'''
new = '''        let selected = draft.selectedRecommendations.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.timeBand.rawValue < $1.timeBand.rawValue
        }
'''
if old in text:
    text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")

path = ROOT / "Mira/Features/Adjustments/SchedulingModeView.swift"
text = path.read_text(encoding="utf-8")
old = '''                ForEach(draft.selectedRecommendations.sorted(by: candidateSort)) { candidate in
                    HStack {
                        Image(systemName: candidate.isRecommended ? "sparkles" : "calendar")
                            .foregroundStyle(candidate.isRecommended ? palette.accent : palette.secondaryText)
                        Text("\\(candidate.day.japaneseShortDate)  \\(candidate.timeBand.title)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if !candidate.conflicts.isEmpty {
                            Text("要確認")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.warning)
                        }
                    }
                }
'''
new = '''                ForEach(rankedSelected(draft)) { candidate in
                    HStack {
                        Image(systemName: candidate.isRecommended ? "sparkles" : "calendar")
                            .foregroundStyle(candidate.isRecommended ? palette.accent : palette.secondaryText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\\(candidate.day.japaneseShortDate)  \\(candidate.timeBand.title)")
                                .font(.subheadline.weight(.semibold))
                            if candidate.id == topRecommendedID(draft) {
                                Text("いちばんおすすめ")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        Spacer()
                        if !candidate.conflicts.isEmpty {
                            Text("要確認")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.warning)
                        }
                    }
                }
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''            if let first = draft.selectedRecommendations.sorted(by: candidateSort).first {
                Text("第一候補：\\(first.day.japaneseShortDate) \\(first.timeBand.title)")
'''
new = '''            if let first = rankedSelected(draft).first {
                Text("いちばんおすすめ：\\(first.day.japaneseShortDate) \\(first.timeBand.title)")
'''
if old in text:
    text = text.replace(old, new, 1)

marker = '''    private func candidateSort(_ lhs: CandidateRecommendation, _ rhs: CandidateRecommendation) -> Bool {
'''
helpers = '''    private func rankedSelected(_ draft: SchedulingDraft) -> [CandidateRecommendation] {
        draft.selectedRecommendations.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return candidateSort($0, $1)
        }
    }

    private func topRecommendedID(_ draft: SchedulingDraft) -> UUID? {
        draft.recommendations
            .filter(\\.isRecommended)
            .max(by: { $0.score < $1.score })?
            .id
    }

'''
if "private func rankedSelected" not in text and marker in text:
    text = text.replace(marker, helpers + marker, 1)
path.write_text(text, encoding="utf-8")
print("Top candidate emphasis applied.")
