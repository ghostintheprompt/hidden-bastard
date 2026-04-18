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
    
    @State private var testPath: String = ""
    @State private var testResult: Bool? = nil

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

            VStack(alignment: .leading, spacing: 4) {
                Text("File Pattern (regex)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("e.g., \\.tmp$", text: Binding<String>(
                        get: { target.pattern ?? "" },
                        set: { target.pattern = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    if let pattern = target.pattern, !pattern.isEmpty {
                        Button("TEST") {
                            testRegex()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            if let pattern = target.pattern, !pattern.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Test path or filename...", text: $testPath)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    
                    if let result = testResult {
                        HStack {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(result ? "MATCH" : "NO MATCH")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(result ? .green : .red)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.1))
                .cornerRadius(4)
            }

            HStack {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text("Min Size (MB)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Size", value: Binding<UInt64>(
                        get: { (target.sizeThreshold ?? 0) / 1_000_000 },
                        set: { target.sizeThreshold = $0 > 0 ? $0 * 1_000_000 : nil }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Min Age (days)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Age", value: Binding<Int>(
                        get: { Int((target.ageThreshold ?? 0) / (24 * 3600)) },
                        set: { target.ageThreshold = $0 > 0 ? TimeInterval($0 * 24 * 3600) : nil }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(AppTheme.cornerRadius)
    }
    
    private func testRegex() {
        guard let pattern = target.pattern, 
              let regex = try? NSRegularExpression(pattern: pattern) else {
            testResult = false
            return
        }
        
        let range = NSRange(location: 0, length: testPath.utf16.count)
        testResult = regex.firstMatch(in: testPath, range: range) != nil
    }
}

struct RulesListView: View {
    @ObservedObject var rulesEngine: RulesEngine
    @State private var editingRule: CleaningRule? = nil
    @State private var showingEditor = false
    @State private var isCreatingNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CLEANING RULES")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(AppTheme.primaryColor)
                Spacer()
                Button(action: {
                    editingRule = nil
                    isCreatingNew = true
                    showingEditor = true
                }) {
                    Label("NEW RULE", systemImage: "plus")
                        .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(AccentButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            if rulesEngine.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.shield")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.primaryColor.opacity(0.4))
                    Text("NO RULES CONFIGURED")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(AppTheme.neutralColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rulesEngine.rules) { rule in
                        HStack {
                            Image(systemName: rule.icon)
                                .frame(width: 24)
                                .foregroundColor(AppTheme.primaryColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name.uppercased())
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                Text(rule.description)
                                    .font(.system(.caption, design: .monospaced))
                                    .opacity(0.6)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { _ in rulesEngine.toggleRule(rule) }
                            ))
                            .toggleStyle(.switch)
                            Button(action: {
                                editingRule = rule
                                isCreatingNew = false
                                showingEditor = true
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                    }
                    .onDelete { rulesEngine.deleteRule(at: $0) }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showingEditor) {
            RuleEditorView(
                rule: isCreatingNew ? nil : editingRule,
                onSave: { rule in
                    if isCreatingNew {
                        rulesEngine.addRule(rule)
                    } else {
                        rulesEngine.updateRule(rule)
                    }
                    showingEditor = false
                },
                onCancel: { showingEditor = false }
            )
        }
    }
}

struct RuleEditorView_Previews: PreviewProvider {
    static var previews: some View {
        RuleEditorView(rule: nil, onSave: { _ in }, onCancel: {})
    }
}
