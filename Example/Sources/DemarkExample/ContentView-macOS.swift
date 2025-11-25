import Demark
import SwiftUI

#if os(macOS)
    extension ContentView {
        var macOSLayout: some View {
            HSplitView {
                // Left Pane - HTML Input
                VStack(alignment: .leading, spacing: 0) {
                    inputHeader

                    Divider()

                    inputEditor

                    Divider()
                        .padding(.top, 8)

                    optionsPanel
                }
                .frame(minWidth: 400, idealWidth: 500)

                // Right Pane - Markdown Output
                VStack(alignment: .leading, spacing: 0) {
                    outputHeader

                    Divider()

                    outputTabs

                    outputContent
                }
                .frame(minWidth: 400, idealWidth: 500)
            }
            .frame(minWidth: 900, minHeight: 600)
            .navigationTitle("Demark Example")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    convertButton
                }
            }
        }
    }
#endif
