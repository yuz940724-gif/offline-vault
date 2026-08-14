import SwiftUI

struct PasswordGeneratorView: View {
    @Environment(\.dismiss) private var dismiss

    var onUse: (String) -> Void

    @State private var options = PasswordGeneratorOptions()
    @State private var generated = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("预览") {
                    Text(generated.isEmpty ? "点击生成" : generated)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("选项") {
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

                Section {
                    Button("重新生成", action: regenerate)
                    Button("复制") {
                        ClipboardService.copySecret(generated)
                    }
                    .disabled(generated.isEmpty)
                    Button("使用这个密码") {
                        onUse(generated)
                        dismiss()
                    }
                    .disabled(generated.isEmpty)
                }
            }
            .navigationTitle("密码生成器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: regenerate)
            .onChange(of: options) { _, _ in
                regenerate()
            }
            .onDisappear {
                generated = ""
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func regenerate() {
        errorMessage = nil
        do {
            generated = try PasswordGenerator.generate(options)
        } catch {
            generated = ""
            errorMessage = "请至少选择一种字符类型"
        }
    }
}
