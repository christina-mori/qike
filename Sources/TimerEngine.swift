import Foundation

enum Phase: String, Codable {
    case focus, rest
    var duration: TimeInterval { self == .focus ? 2400 : 300 }
    var title: String { self == .focus ? "专注时间" : "休息时间" }
    var next: Phase { self == .focus ? .rest : .focus }
}

struct FocusSpan: Codable, Identifiable {
    var start: Date
    var end: Date
    var id: Date { start }
    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

struct TimerEngine: Codable {
    static let focusOptions = [25, 30, 35, 40, 45]
    var focusMinutes: Int = 40
    var phase: Phase = .focus
    var remaining: TimeInterval = 2400
    var deadline: Date?
    var completed: [Date] = []
    var spans: [FocusSpan] = []
    var activeStart: Date?
    var earlyEnds: [Date] = []
    var running: Bool { deadline != nil }
    var phaseDuration: TimeInterval { phase == .focus ? TimeInterval(focusMinutes * 60) : 300 }

    init() {}
    enum CodingKeys: String, CodingKey { case focusMinutes, phase, remaining, deadline, completed, spans, activeStart, earlyEnds }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let savedMinutes = try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 40
        focusMinutes = Self.focusOptions.contains(savedMinutes) ? savedMinutes : 40
        phase = try values.decode(Phase.self, forKey: .phase)
        remaining = try values.decode(TimeInterval.self, forKey: .remaining)
        deadline = try values.decodeIfPresent(Date.self, forKey: .deadline)
        completed = try values.decodeIfPresent([Date].self, forKey: .completed) ?? []
        // Preserve completed sessions from versions without an interval ledger.
        spans = try values.decodeIfPresent([FocusSpan].self, forKey: .spans)
            ?? completed.map { FocusSpan(start: $0.addingTimeInterval(-2400), end: $0) }
        activeStart = try values.decodeIfPresent(Date.self, forKey: .activeStart)
        if !values.contains(.spans), phase == .focus, let end = deadline { activeStart = end.addingTimeInterval(-2400) }
        earlyEnds = try values.decodeIfPresent([Date].self, forKey: .earlyEnds) ?? []
    }
    mutating func start(at now: Date) {
        guard !running else { return }
        deadline = now.addingTimeInterval(remaining)
        if phase == .focus { activeStart = now }
    }
    mutating func setFocusMinutes(_ minutes: Int, at now: Date) {
        guard Self.focusOptions.contains(minutes) else { return }
        _ = advance(to: now)
        let elapsed = phase == .focus ? max(0, phaseDuration - remaining) : 0
        focusMinutes = minutes
        guard phase == .focus else { return }
        remaining = max(0, phaseDuration - elapsed)
        if remaining == 0 {
            let wasRunning = running
            finishSpan(at: now)
            completed.append(now)
            phase = .rest
            remaining = 300
            deadline = wasRunning ? now.addingTimeInterval(300) : nil
        } else if running { deadline = now.addingTimeInterval(remaining) }
    }
    mutating func finishSpan(at end: Date) {
        if let start = activeStart, end > start { spans.append(FocusSpan(start: start, end: end)) }
        activeStart = nil
    }
    mutating func pause(at now: Date) {
        _ = advance(to: now)
        remaining = max(0, deadline?.timeIntervalSince(now) ?? remaining)
        if phase == .focus { finishSpan(at: now) }
        deadline = nil
    }
    mutating func reset(at now: Date = Date()) {
        pause(at: now)
        remaining = phaseDuration
    }
    mutating func skip() {
        phase = phase.next
        remaining = phaseDuration
        deadline = nil
        activeStart = nil
    }
    mutating func endFocus(at now: Date) {
        _ = advance(to: now)
        guard phase == .focus else { return }
        let wasRunning = running
        let hadProgress = remaining < phaseDuration
        pause(at: now)
        if hadProgress { earlyEnds.append(now) }
        phase = .rest
        remaining = phaseDuration
        deadline = wasRunning ? now.addingTimeInterval(remaining) : nil
    }
    // Absolute deadlines preserve the cycle across sleep and delayed timer ticks.
    @discardableResult mutating func advance(to now: Date) -> Int {
        var transitions = 0
        while let end = deadline, end <= now {
            if phase == .focus {
                finishSpan(at: end)
                completed.append(end)
            }
            phase = phase.next
            remaining = phaseDuration
            deadline = end.addingTimeInterval(remaining)
            activeStart = phase == .focus ? end : nil
            transitions += 1
        }
        let cutoff = now.addingTimeInterval(-86400 * 30)
        completed.removeAll { $0 < cutoff }
        spans.removeAll { $0.end < cutoff }
        earlyEnds.removeAll { $0 < cutoff }
        if let end = deadline { remaining = max(0, end.timeIntervalSince(now)) }
        return transitions
    }
    func todayCount(at now: Date = Date()) -> Int {
        completed.filter { Calendar.current.isDate($0, inSameDayAs: now) }.count
    }
    func todaySpans(at now: Date = Date()) -> [FocusSpan] {
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        var entries = spans
        if let activeStart, phase == .focus, running {
            entries.append(FocusSpan(start: activeStart, end: min(now, deadline!)))
        }
        return entries.compactMap { span in
            let a = max(start, span.start), b = min(end, span.end)
            return b > a ? FocusSpan(start: a, end: b) : nil
        }.sorted { $0.start > $1.start }
    }
    func todayFocusSeconds(at now: Date = Date()) -> TimeInterval {
        todaySpans(at: now).reduce(0) { $0 + $1.duration }
    }
}
