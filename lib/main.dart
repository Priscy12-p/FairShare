import 'package:flutter/material.dart';
// Imports Flutter's widgets for building the user interface.

import 'package:firebase_core/firebase_core.dart';
// Allows our app to connect to Firebase.

import 'firebase_options.dart';
// Contains the Firebase settings generated for this project.

// main() is the starting point of every Dart application.
// async allows us to wait for Firebase to initialize.
Future<void> main() async {
  // Prepares Flutter before running asynchronous code.
  WidgetsFlutterBinding.ensureInitialized();

  // Connects FairShare to the configured Firebase project.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Starts our application.
  runApp(const FairShareApp());
}

// This is the root widget of the FairShare application.
// StatelessWidget is used because this widget itself
// does not manage changing task data.
class FairShareApp extends StatelessWidget {
  const FairShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Sets the application's name.
      title: 'FairShare',

      // Hides the DEBUG banner in the top-right corner.
      debugShowCheckedModeBanner: false,

      // Defines the application's visual theme.
      theme: ThemeData(
        // Creates a colour scheme based on purple.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),

        // Uses Material Design 3 components.
        useMaterial3: true,
      ),

      // Displays our home screen when the app opens.
      home: const TaskHomePage(),
    );
  }
}

// A Task object represents one task in our list.
// Each task has a title and a completion status.
class Task {
  Task({required this.title, this.isCompleted = false});

  // The description entered for this task.
  String title;

  // false means outstanding; true means completed.
  bool isCompleted;
}

// StatefulWidget is used because the task list changes
// when a user adds, completes, or deletes a task.
class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

// This class manages the changing data on the home screen.
class _TaskHomePageState extends State<TaskHomePage> {
  // Controller reads and clears the text input field.
  final TextEditingController taskController = TextEditingController();

  // Sample tasks shown when the app first opens.
  final List<Task> tasks = [
    Task(title: 'Create my first task'),
    Task(title: 'Learn Flutter widgets'),
    Task(title: 'Build the FairShare interface'),
  ];

  // Adds a task using the text entered by the user.
  void addTask() {
    // trim() removes unnecessary spaces at the beginning
    // and end of the entered text.
    final String taskName = taskController.text.trim();

    // Prevents empty tasks from being added.
    if (taskName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task first.')),
      );
      return;
    }

    // setState tells Flutter to redraw the interface
    // after the task list changes.
    setState(() {
      tasks.add(Task(title: taskName));

      // Clears the input field after adding a task.
      taskController.clear();
    });
  }

  // Changes a task's status when its checkbox is clicked.
  void toggleTask(int index, bool? isChecked) {
    setState(() {
      // The index identifies which task was selected.
      // ?? false provides a default if the value is null.
      tasks[index].isCompleted = isChecked ?? false;
    });
  }

  // Deletes the task at the selected list position.
  void deleteTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
  }

  @override
  void dispose() {
    // Releases the controller when the screen is removed.
    // This helps prevent unnecessary resource usage.
    taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Counts the tasks that have been completed.
    final int completedCount = tasks.where((task) => task.isCompleted).length;

    // Scaffold provides the basic screen structure:
    // an app bar and a body.
    return Scaffold(
      // The top navigation bar displays the app title.
      appBar: AppBar(
        title: const Text(
          'FairShare',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      // SafeArea keeps content away from screen cut-outs.
      body: SafeArea(
        child: Padding(
          // Adds space around the screen content.
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main heading on the home screen.
              const Text(
                'My Tasks',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              // Shows completed tasks compared with all tasks.
              Text(
                '$completedCount of ${tasks.length} tasks completed',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),

              const SizedBox(height: 24),

              // Row places the input field and Add button
              // next to each other.
              Row(
                children: [
                  // Expanded lets the input use available space.
                  Expanded(
                    child: TextField(
                      controller: taskController,
                      decoration: const InputDecoration(
                        hintText: 'Enter a new task...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_note),
                      ),

                      // Pressing Enter also adds the task.
                      onSubmitted: (_) => addTask(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Button that adds the entered task.
                  ElevatedButton(
                    onPressed: addTask,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Expanded gives the list the remaining height.
              Expanded(
                // Shows a helpful message if no tasks remain.
                child: tasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No tasks yet. Add your first task!',
                          textAlign: TextAlign.center,
                        ),
                      )
                    // ListView.builder creates a list of tasks.
                    // It builds list items as they are needed.
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          // Gets the task at this position.
                          final Task task = tasks[index];

                          // Card gives each task a separate surface.
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              // Checkbox marks a task as completed.
                              leading: Checkbox(
                                value: task.isCompleted,
                                onChanged: (value) {
                                  toggleTask(index, value);
                                },
                              ),

                              // Completed tasks are crossed out
                              // and displayed in grey.
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: task.isCompleted ? Colors.grey : null,
                                ),
                              ),

                              // Delete icon removes the task.
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete task',
                                onPressed: () => deleteTask(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
