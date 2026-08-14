import SwiftUI

struct PasswordGeneratorView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    var initialPassword: String = ""
    var onPick: ((String) -> Void)?

    @State private var options = PasswordGeneratorOptions()
    @State private var generated = ""
    @State private var errorMessage: String?
    @State private var banner: String?
    @State private var showingSave = false
    @State private var saveTitle = ""
    @State private var saveUsername = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(generated.isEmpty ? "正在生成" : generated)
                        .font(.title3.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                    HStack {
                        Button("换一条", action: regenerate)
                            .nativeGlassButton()
                        Button("复制", action: copyCurrent)
                            .nativeGlassButton()
                            .disabled(generated.isEmpty)
                        Button("保存") {
                            if let onPick {
                                onPick(generated)
                                dismiss()
                            } else {
                                showingSave = true
                            }
                        }
                        .nativeProminentButton()
                        .disabled(generated.isEmpty)
                    }
                    .listRowBackground(Color.clear)
                }

                Section("规则") {
                    Stepper(value: $options.length, in: PasswordGeneratorOptions.lengthRange) {
                        Text("长度 \(options.length)")
                    }
                    Toggle("大写字母", isOn: $options.uppercase)
                    Toggle("小写字母", isOn: $options.lowercase)
                    Toggle("数字", isOn: $options.digits)
                    Toggle("符号", isOn: $options.symbols)
                    Toggle("排除易混字符", isOn: $options.excludeAmbiguous)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("复杂密码生成器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                if let banner {
                    CopyBanner(text: banner)
                        .padding(.top, 8)
                }
            }
            .sheet(isPresented: $showingSave) {
                saveSheet
            }
            .onAppear {
                if generated.isEmpty {
                    if initialPassword.isEmpty {
                        regenerate()
                    } else {
                        generated = initialPassword
                    }
                }
            }
            .onChange(of: options) { _, _ in
                regenerate()
            }
            .onDisappear {
                if onPick == nil {
                    generated = ""
                }
            }
        }
    }

    private var saveSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $saveTitle)
                    TextField("账号", text: $saveUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LabeledContent("密码", value: generated)
                        .font(.body.monospaced())
                }
            }
            .navigationTitle("保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showingSave = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveGenerated()
                    }
                    .disabled(saveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func regenerate() {
        errorMessage = nil
        do {
            generated = try PasswordGenerator.generate(options)
        } catch {
            generated = ""
            errorMessage = "请至少选择一种字符"
        }
    }

    private func copyCurrent() {
        guard !generated.isEmpty else { return }
        ClipboardService.copySecret(generated)
        banner = ClipboardService.copiedSecretMessage
        Task {
            try? await Task.sleep(for: .seconds(2))
            banner = nil
        }
    }

    private func saveGenerated() {
        do {
            try vault.create(
                title: saveTitle,
                username: saveUsername,
                password: generated,
                url: nil,
                notes: nil,
                category: nil,
                isFavorite: false
            )
            showingSave = false
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingSave = false
        }
    }
}
