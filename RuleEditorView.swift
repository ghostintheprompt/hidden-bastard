import SwiftUI

struct RuleEditorView: View {
    let rule: CleaningRule?
    let onSave: (CleaningRule) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var schedule: RuleSchedule
    @State private var isEnabled: Bool
    @State private var targets: [RuleTarget]

    init(rule: CleaningRule?, onSave: @escaping (CleaningRule) -> Void, onCancel: @escaping () -> Void) {
        self.rule = rule
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize state from rule or defaults
        _name = State(initialValue: rule?.name ?? "")
        _description = State(initialValue: rule?.description ?? "")
        _icon = State(initialValue: rule?.icon ?? "folder")
        _schedule = State(initialValue: rule?.schedule ?? .weekly)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
        _targets = State(initialValue: rule?.targets ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(rule == nil ? "Create Rule" : "Edit Rule")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                    // Basic info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rule Name")
                            .font(.headline)

                        TextField("e.g., Clean Downloads", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        TextField("What does this rule do?", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Icon selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(["folder", "arrow.down.circle", "doc.text", "hammer", "trash", "cube.box"], id: \.self) { iconName in
                                Button(action: {
                                    icon = iconName
                                }) {
                                    Image(systemName: iconName)
                                        .font(.title2)
                                        .foregroundColor(icon == iconName ? .white : .blue)
                                        .frame(width: 40, height: 40)
                                        .background(icon == iconName ? Color.blue : Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Schedule
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schedule")
                            .font(.headline)

                        Picker("Schedule", selection: $schedule) {
                            ForEach(RuleSchedule.allCases, id: \.self) { scheduleOption in
                                Text(scheduleOption.rawValue).tag(scheduleOption)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Targets
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Targets")
                                .font(.headline)

                            Spacer()

                            Button(action: {
                                targets.append(RuleTarget(
                                    path: "~/Downloads",
                                    pattern: nil,
                                    sizeThreshold: 10_000_000,
                                    ageThreshold: nil,
                                    action: .moveToTrash
                                ))
                            }) {
                                Label("Add Target", systemImage: "plus.circle")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderless)
                        }

                        if targets.isEmpty {
                            Text("No targets added. Click 'Add Target' to get started.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                                TargetEditorRow(
                                    target: binding(for: index),
                                    onDelete: {
                                        targets.remove(at: index)
                                    }
                                )
                            }
                        }
                    }

                    // Enabled toggle
                    Toggle("Enable this rule", isOn: $isEnabled)
                        .toggleStyle(CustomToggleStyle())
                }
                .padding()
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Spacer()

                Button("Save Rule") {
                    let newRule = CleaningRule(
                        id: rule?.id ?? UUID(),
                        name: name,
                        description: description,
                        icon: icon,
                        targets: targets,
                        schedule: schedule,
                        isEnabled: isEnabled,
                        lastRun: rule?.lastRun
                    )
                    onSave(newRule)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(name.isEmpty || description.isEmpty || targets.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
    }

    private func binding(for index: Int) -> Binding<RuleTarget> {
        Binding(
            get: { targets[index] },
            set: { targets[index] = $0 }
        )
    }
}

// Row for editing a rule target
struct TargetEditorRow: View {
    @Binding var target: RuleTarget
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Target Path")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            TextField("Path to scan", text: $target.path)
                .textFieldStyle(.roundedBorder)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("File Pattern (regex)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("e.g., \\.tmp$", text: Binding(
                        get: { target.pattern ?? "" },
                        set: { target.pattern = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Action")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $target.action) {
                        ForEach(RuleAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min Size (MB)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Size", value: Binding(
                        get: { (target.sizeThreshold ?? 0) / 1_000_000 },
                        set: { target.sizeThreshold = $0 > 0 ? $0 * 1_000_000 : nil }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Min Age (days)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Age", value: Binding(
                        get: { (target.ageThreshold ?? 0) / (24 * 3600) },
                        set: { target.ageThreshold = $0 > 0 ? $0 * 24 * 3600 : nil }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(AppTheme.cornerRadius)
    }
}

struct RuleEditorView_Previews: PreviewProvider {
    static var previews: some View {
        RuleEditorView(rule: nil, onSave: { _ in }, onCancel: {})
    }
}
