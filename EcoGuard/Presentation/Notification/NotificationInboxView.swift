import SwiftUI

struct NotificationInboxView: View {
    let repository: (any NotificationInboxRepository)?
    @Environment(\.dismiss) private var dismiss
    @State private var inbox: NotificationInbox?
    @State private var isBusy = false
    @State private var loadFailed = false
    @State private var updateFailed = false
    @State private var selected: InboxNotification?

    var body: some View {
        NavigationStack {
            Group {
                if let inbox {
                    if inbox.notifications.isEmpty {
                        ContentUnavailableView("받은 알림이 없어요", systemImage: "bell")
                    } else {
                        List {
                            Section {
                                ForEach(inbox.notifications) { notification in
                                    Button {
                                        selected = notification
                                        if !notification.isRead {
                                            Task { await reload(after: .read(notification.id)) }
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Label(notification.title, systemImage: notification.isRead ? "bell" : "bell.badge")
                                                .font(.headline)
                                            Text(notification.body)
                                            Text(notification.createdAt.prefix(10))
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.primary)
                                    }
                                    .disabled(isBusy)
                                }
                            } header: {
                                Text("읽지 않은 알림 \(inbox.unreadCount)개")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial, in: Capsule())
                            }
                        }
                        .refreshable { await reload() }
                    }
                } else if loadFailed {
                    ContentUnavailableView {
                        Label("알림을 불러오지 못했어요", systemImage: "bell.slash")
                    } actions: {
                        Button("다시 시도") { Task { await reload() } }
                            .disabled(isBusy)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("알림함")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("모두 읽음") {
                        Task { await reload(after: .readAll) }
                    }
                    .disabled(isBusy || (inbox?.unreadCount ?? 0) == 0)
                }
            }
            .task { await reload() }
            .sheet(item: $selected) { notification in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(notification.title).font(.headline)
                        Text(notification.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .presentationDetents([.medium, .large])
            }
            .alert("알림을 갱신하지 못했어요", isPresented: $updateFailed) {
                Button("확인", role: .cancel) {}
            }
        }
    }

    private enum ReadAction {
        case read(Int64)
        case readAll
    }

    private func reload(after mutation: ReadAction? = nil) async {
        guard !isBusy else { return }
        guard let repository else {
            loadFailed = true
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch mutation {
            case .read(let id): try await repository.markRead(id: id)
            case .readAll: try await repository.markAllRead()
            case nil: break
            }
            inbox = try await repository.fetchInbox()
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            if inbox == nil {
                loadFailed = true
            } else {
                updateFailed = true
            }
        }
    }
}
