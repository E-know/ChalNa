import Foundation
import os

/// 공급자의 completion을 기다리지 않고도 취소하거나, 실제 전송이 멎었을 때 해당 항목만 종료한다.
final class PickedMediaTransfer: Sendable {
    private struct State {
        var lastActivity = ContinuousClock.now
        var fraction = 0.0
        var finished = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let idleTimeout: Duration
    private let onProgress: @Sendable (Double) -> Void

    init(idleTimeout: Duration = .seconds(60), onProgress: @escaping @Sendable (Double) -> Void) {
        self.idleTimeout = idleTimeout
        self.onProgress = onProgress
    }

    func receivedBytes() {
        state.withLock { $0.lastActivity = .now }
    }

    /// 폴백을 시도해도 사용자에게 보이는 진행률은 감소하지 않는다.
    func progress(upTo end: Double) -> @Sendable (Double) -> Void {
        let start = state.withLock { $0.fraction }
        return { fraction in
            guard fraction.isFinite else { return }
            let value = start + min(1, max(0, fraction)) * (end - start)
            let changed = self.state.withLock { state in
                guard !state.finished, value > state.fraction else { return false }
                state.fraction = value
                state.lastActivity = .now
                return true
            }
            if changed { self.onProgress(value) }
        }
    }

    func run<Value: Sendable>(_ operation: @escaping @Sendable () async -> Value?) async -> Value? {
        guard !Task.isCancelled else { return nil }
        let (results, completion) = AsyncStream<Value>.makeStream()
        let worker = Task {
            if let value = await operation() { completion.yield(value) }
            completion.finish()
        }
        let watchdog = Task {
            while !Task.isCancelled {
                let remaining = state.withLock { state in
                    ContinuousClock.now.duration(to: state.lastActivity.advanced(by: idleTimeout))
                }
                guard remaining > .zero else {
                    completion.finish()
                    return
                }
                do { try await Task.sleep(for: remaining) } catch { return }
            }
        }
        defer {
            state.withLock { $0.finished = true }
            worker.cancel()
            watchdog.cancel()
        }
        var iterator = results.makeAsyncIterator()
        let value = await iterator.next()
        return Task.isCancelled ? nil : value
    }
}
