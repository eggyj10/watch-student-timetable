import SwiftUI

/// Adds a subject or a teacher without leaving whatever you were editing.
struct QuickAddView: View {

    enum Kind {
        case subject
        case teacher

        var title: String {
            switch self {
            case .subject: return "New Subject"
            case .teacher: return "New Teacher"
            }
        }

        var codePrompt: String {
            switch self {
            case .subject: return "Code, e.g. SCI102B"
            case .teacher: return "Code, e.g. DAYLU"
            }
        }

        var namePrompt: String {
            switch self {
            case .subject: return "Name, e.g. Science"
            case .teacher: return "Name, e.g. Mr Day"
            }
        }

        var footer: String {
            switch self {
            case .subject:
                return "The code is what appears on your printed timetable. The name is what the watch shows."
            case .teacher:
                return "The code is what appears on your printed timetable."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let kind: Kind
    /// Called with the trimmed, upper-cased code and the trimmed name.
    let onAdd: (String, String) -> Void

    @State private var code = ""
    @State private var name = ""

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespaces).uppercased()
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isValid: Bool { !trimmedCode.isEmpty && !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind.codePrompt, text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(kind.namePrompt, text: $name)
                } footer: {
                    Text(kind.footer)
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(trimmedCode, trimmedName)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
