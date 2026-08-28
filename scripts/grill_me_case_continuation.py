#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "Mira/App/MiraStore+Conversation.swift"
text = PATH.read_text(encoding="utf-8")

old = '''        let interpretation = await conversationInterpreter.interpret(
            text: text,
            now: now,
            pinnedContext: effectivePinned,
            searchCandidates: automaticCandidates,
            recentTurns: recentTurns
        )
        pendingInterpretation = interpretation

        let resolvedContext = effectivePinned ?? resolvedAutomaticContext(from: automaticCandidates)
'''
new = '''        let resolvedContext = effectivePinned ?? resolvedAutomaticContext(from: automaticCandidates)
        var interpretation = await conversationInterpreter.interpret(
            text: text,
            now: now,
            pinnedContext: effectivePinned,
            searchCandidates: automaticCandidates,
            recentTurns: recentTurns
        )
        interpretation = enrichConversationInterpretation(
            interpretation,
            text: text,
            contextResult: resolvedContext
        )
        pendingInterpretation = interpretation
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''        draft = recommendations(for: draft, preserveManualSelection: false)

        if !interpretation.candidateDates.isEmpty {
'''
new = '''        draft = recommendations(for: draft, preserveManualSelection: false)
        draft = applySchedulingConstraints(draft, constraints: interpretation.explicitConstraints)

        if !interpretation.candidateDates.isEmpty {
'''
if old in text:
    text = text.replace(old, new, 1)

# Replace creation-only branches with update-or-create behavior.
old = '''        if activeSchedulingIntent == .checkInvitation {
            let entity = PendingInvitationEntity(
                title: draft.title,
                contactName: draft.person,
                status: .considering,
                candidates: candidates,
                conversationCaseID: caseEntity?.id
            )
            context.insert(entity)
            if let caseEntity {
                caseEntity.kind = .invitation
                caseEntity.status = .active
                var state = caseEntity.state
                state.relatedInvitationID = entity.id
                state.candidates = candidates
                state.durationBucket = draft.durationBucket
                state.allowedTimeBands = draft.timeBands
                caseEntity.state = state
                caseEntity.appendTurn(role: .assistant, text: "候補を整理したにゃ。参加するか、別の日を探すか決められるよ。", at: now)
            }
        } else {
            let entity = AdjustmentEntity(
                title: draft.title,
                contactName: draft.person,
                status: .waiting,
                candidates: candidates,
                generatedMessage: message,
                conversationCaseID: caseEntity?.id
            )
            context.insert(entity)
            if let caseEntity {
                caseEntity.kind = .adjustment
                caseEntity.status = .waiting
                var state = caseEntity.state
                state.relatedAdjustmentID = entity.id
                state.candidates = candidates
                state.durationBucket = draft.durationBucket
                state.allowedTimeBands = draft.timeBands
                caseEntity.state = state
                caseEntity.appendTurn(role: .assistant, text: "この候補を仮押さえしたにゃ。相手へ送る文も作ったよ。", at: now)
            }
        }
'''
new = '''        if activeSchedulingIntent == .checkInvitation {
            let existingInvitation = caseEntity?.state.relatedInvitationID.flatMap { invitationID in
                pendingInvitations.first(where: { $0.id == invitationID })
            }
            let invitation: PendingInvitationEntity
            if let existingInvitation {
                invitation = existingInvitation
                invitation.title = draft.title
                invitation.contactName = draft.person
                invitation.candidates = candidates
                invitation.status = .considering
                invitation.updatedAt = now
            } else {
                invitation = PendingInvitationEntity(
                    title: draft.title,
                    contactName: draft.person,
                    status: .considering,
                    candidates: candidates,
                    conversationCaseID: caseEntity?.id
                )
                context.insert(invitation)
            }
            if let caseEntity {
                caseEntity.kind = .invitation
                caseEntity.status = .active
                var state = caseEntity.state
                state.relatedInvitationID = invitation.id
                state.candidates = candidates
                state.durationBucket = draft.durationBucket
                state.allowedTimeBands = draft.timeBands
                state.explicitConstraints = Array(Set(state.explicitConstraints))
                state.lastIntent = .checkInvitation
                caseEntity.state = state
                caseEntity.appendTurn(role: .assistant, text: "候補を整理し直したにゃ。参加するか、別の日を探すか決められるよ。", at: now)
            }
        } else {
            let existingAdjustment = caseEntity?.state.relatedAdjustmentID.flatMap { adjustmentID in
                adjustments.first(where: { $0.id == adjustmentID })
            }
            let adjustment: AdjustmentEntity
            if let existingAdjustment {
                adjustment = existingAdjustment
                adjustment.title = draft.title
                adjustment.contactName = draft.person
                adjustment.candidates = candidates
                adjustment.generatedMessage = message
                adjustment.status = .waiting
                adjustment.updatedAt = now
            } else {
                adjustment = AdjustmentEntity(
                    title: draft.title,
                    contactName: draft.person,
                    status: .waiting,
                    candidates: candidates,
                    generatedMessage: message,
                    conversationCaseID: caseEntity?.id
                )
                context.insert(adjustment)
            }
            if let caseEntity {
                caseEntity.kind = .adjustment
                caseEntity.status = .waiting
                var state = caseEntity.state
                state.relatedAdjustmentID = adjustment.id
                state.candidates = candidates
                state.durationBucket = draft.durationBucket
                state.allowedTimeBands = draft.timeBands
                state.lastIntent = .findDates
                caseEntity.state = state
                caseEntity.appendTurn(role: .assistant, text: "この候補を仮押さえしたにゃ。相手へ送る文も作り直したよ。", at: now)
            }
        }
'''
if old in text:
    text = text.replace(old, new, 1)

PATH.write_text(text, encoding="utf-8")
print("Structured case continuation wired.")
