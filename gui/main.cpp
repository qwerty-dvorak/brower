/*
 * A cross-platform, minimal, modern Firefox profile chooser built with Qt6.
 *
 * This single source file is designed to be compiled on Linux, Windows, and macOS.
 */
#include <QApplication>
#include <QWidget>
#include <QPushButton>
#include <QVBoxLayout>
#include <QProcess>
#include <QCoreApplication>
#include <QString>
#include <QStringList>
#include <QStandardPaths>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <algorithm>

// Function to get the path to profiles.ini on different operating systems
std::string getProfilesPath() {
#if defined(_WIN32)
    // Windows: %APPDATA%\Mozilla\Firefox\profiles.ini
    const char* appdata = getenv("APPDATA");
    if (appdata) {
        return std::string(appdata) + "\\Mozilla\\Firefox\\profiles.ini";
    }
#elif defined(__APPLE__)
    // macOS: ~/Library/Application Support/Firefox/profiles.ini
    const char* home = getenv("HOME");
    if (home) {
        return std::string(home) + "/Library/Application Support/Firefox/profiles.ini";
    }
#else
    // Linux: ~/.mozilla/firefox/profiles.ini
    const char* home = getenv("HOME");
    if (home) {
        return std::string(home) + "/.mozilla/firefox/profiles.ini";
    }
#endif
    return ""; // Return empty string if path could not be determined
}

// Function to apply a modern, dark stylesheet to the application
void setModernStyle(QApplication &app) {
    app.setStyleSheet(R"(
        QWidget {
            background-color: #2E3440;
            color: #D8DEE9;
            font-family: sans-serif;
            font-size: 14px;
        }
        QPushButton {
            background-color: #4C566A;
            border: none;
            padding: 10px;
            border-radius: 5px;
            min-height: 25px;
        }
        QPushButton:hover {
            background-color: #5E81AC;
        }
        QPushButton:pressed {
            background-color: #81A1C1;
        }
    )");
}

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    setModernStyle(app);

    QString clickedUrl;
    if (QCoreApplication::arguments().size() < 2) {
        std::cerr << "Usage: " << argv[0] << " <URL>" << std::endl;
        return 1;
    }
    clickedUrl = QCoreApplication::arguments().at(1);

    std::string profiles_path = getProfilesPath();
    if (profiles_path.empty()) {
        std::cerr << "Could not determine the path to Firefox profiles." << std::endl;
        return 1;
    }

    std::ifstream profiles_file(profiles_path);
    std::vector<std::string> profile_names;
    std::string line;
    if (profiles_file.is_open()) {
        while (getline(profiles_file, line)) {
            if (line.rfind("Name=", 0) == 0) {
                profile_names.push_back(line.substr(5));
            }
        }
        profiles_file.close();
    } else {
        std::cerr << "Could not open " << profiles_path << std::endl;
        return 1;
    }

    if (profile_names.empty()) {
        std::cerr << "No profiles found in " << profiles_path << std::endl;
        return 1;
    }

    QWidget window;
    window.setWindowTitle("Choose Firefox Profile");
    window.setMinimumWidth(450);
    window.setWindowFlags(Qt::Dialog | Qt::WindowStaysOnTopHint);

    QVBoxLayout *layout = new QVBoxLayout(&window);
    layout->setSpacing(10);
    layout->setContentsMargins(15, 15, 15, 15);

    for (const auto &profile_str : profile_names) {
        QString profileName = QString::fromStdString(profile_str);
        QPushButton *button = new QPushButton(profileName);
        layout->addWidget(button);

        QObject::connect(button, &QPushButton::clicked, [profileName, clickedUrl]() {
            QStringList args = {"-P", profileName, clickedUrl};
            // QProcess::startDetached is fully cross-platform
            QProcess::startDetached("firefox", args);
            QApplication::quit();
        });
    }

    window.setLayout(layout);
    window.adjustSize(); // Adjust window size to fit contents
    window.show();

    return app.exec();
}