/*
 * A minimal, modern Firefox profile chooser built with Qt6.
 *
 * To compile, you will need the Qt6 development libraries:
 * - On Arch Linux: sudo pacman -S qt6-base
 * - On Debian/Ubuntu (if available): sudo apt-get install qt6-base-dev
 *
 * Then, you can use the provided Makefile (`make`).
 */
#include <QApplication>
#include <QWidget>
#include <QPushButton>
#include <QVBoxLayout>
#include <QProcess>
#include <QCoreApplication>
#include <QString>
#include <QStringList>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <algorithm>

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

    // 1. Get the URL from command line arguments using Qt's argument handler
    QString clickedUrl;
    if (QCoreApplication::arguments().size() < 2) {
        std::cerr << "Usage: " << argv[0] << " <URL>" << std::endl;
        return 1;
    }
    clickedUrl = QCoreApplication::arguments().at(1);

    // 2. Find and parse profiles.ini (this logic is unchanged)
    std::string home_dir = getenv("HOME");
    std::string profiles_path = home_dir + "/.mozilla/firefox/profiles.ini";
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

    // 3. Create the GUI Window and Layout
    QWidget window;
    window.setWindowTitle("Choose Firefox Profile");
    
    // Calculate window dimensions based on number of profiles
    int windowHeight = std::min(800, 75 * static_cast<int>(profile_names.size()));
    window.setFixedSize(600, windowHeight);
    
    // Set window flags to ensure it appears as a floating window on X11
    window.setWindowFlags(Qt::Window | Qt::WindowStaysOnTopHint);

    // A vertical layout automatically arranges widgets top-to-bottom
    QVBoxLayout *layout = new QVBoxLayout(&window);
    layout->setSpacing(10);
    layout->setContentsMargins(15, 15, 15, 15);

    // 4. Create a button for each profile and connect its click event
    for (const auto &profile_str : profile_names) {
        QString profileName = QString::fromStdString(profile_str);
        QPushButton *button = new QPushButton(profileName);
        layout->addWidget(button);

        // Use a C++11 lambda for the callback (the modern signal/slot syntax)
        QObject::connect(button, &QPushButton::clicked, [profileName, clickedUrl]() {
            // Use QProcess::startDetached to launch Firefox and immediately exit.
            // This is the platform-independent Qt equivalent of fork/exec.
            QStringList args = {"-P", profileName, clickedUrl};
            QProcess::startDetached("firefox", args);
            QApplication::quit(); // Close the chooser app
        });
    }

    window.setLayout(layout);
    window.show();

    return app.exec();
}