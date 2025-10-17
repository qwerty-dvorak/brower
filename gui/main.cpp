// To compile: g++ main.cpp -lfltk -o profile-chooser
// Make sure you have FLTK installed (e.g., `sudo apt-get install libfltk1.3-dev`)

#include <FL/Fl.H>
#include <FL/Fl_Window.H>
#include <FL/Fl_Button.H>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstdlib> // For getenv
#include <unistd.h> // For fork/exec
#include <cstring> // for strcpy

// Global to hold the URL
std::string clicked_url;

// Callback function for when a profile button is clicked
void profile_button_callback(Fl_Widget* w, void* data) {
    (void)w; // silence unused parameter warning
    const char* profile_name = (const char*)data;
    
    // Fork a new process to run Firefox so our chooser can exit immediately
    pid_t pid = fork();
    if (pid == 0) { // This is the child process
        execlp("firefox", "firefox", "-P", profile_name, clicked_url.c_str(), (char*)NULL);
        // If execlp returns, it means there was an error
        perror("execlp failed");
        exit(1);
    }
    
    // Parent process just exits
    exit(0);
}

int main(int argc, char **argv) {
    // 1. Get the URL from the command line arguments
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <URL>" << std::endl;
        return 1;
    }
    clicked_url = argv[1];

    // 2. Find and parse profiles.ini
    std::string home_dir = getenv("HOME");
    std::string profiles_path = home_dir + "/.mozilla/firefox/profiles.ini";
    std::ifstream profiles_file(profiles_path);
    
    std::vector<std::string> profile_names;
    std::string line;
    if (profiles_file.is_open()) {
        while (getline(profiles_file, line)) {
            if (line.rfind("Name=", 0) == 0) { // Check if the line starts with "Name="
                profile_names.push_back(line.substr(5));
            }
        }
        profiles_file.close();
    } else {
        std::cerr << "Could not open profiles.ini" << std::endl;
        return 1;
    }
    
    // 3. Create the GUI Window
    int window_width = 400;
    int window_height = (profile_names.size() + 1) * 40;
    Fl_Window *window = new Fl_Window(window_width, window_height, "Choose Firefox Profile");

    // 4. Create a button for each profile
    for (size_t i = 0; i < profile_names.size(); ++i) {
        // We need to store the button labels persistently
        char* label = new char[profile_names[i].length() + 1];
        strcpy(label, profile_names[i].c_str());
        
        Fl_Button *button = new Fl_Button(10, 10 + i * 40, window_width - 20, 30, label);
        button->callback(profile_button_callback, (void*)label);
    }

    window->end();
    window->show(argc, argv);
    
    return Fl::run();
}