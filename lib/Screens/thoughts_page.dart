import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';
import '../models/audio_note.dart';
import '../models/user_category.dart';
import '../config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ThoughtsPage extends StatefulWidget {
  final bool autoTranscribe;
  
  const ThoughtsPage({this.autoTranscribe = false});
  
  @override
  State<ThoughtsPage> createState() => _ThoughtsPageState();
}

class _ThoughtsPageState extends State<ThoughtsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  late Box<AudioNote> audioBox;
  late Box<UserCategory> categoryBox;
  List<AudioNote> notes = [];
  List<UserCategory> categories = [];
  Map<String, bool> transcribing = {};
  String statusMessage = 'Loading thoughts...';
  
  final audioPlayer = AudioPlayer();
  String? currentlyPlaying;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    audioBox = Hive.box<AudioNote>('audioNotes');
    categoryBox = Hive.box<UserCategory>('categories');
    loadCategories();
    loadNotes();
    
    audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
        currentlyPlaying = null;
      });
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  void loadCategories() {
    setState(() {
      categories = categoryBox.values.toList();
    });
  }

  Future<void> loadNotes() async {
    try {
      setState(() {
        notes = audioBox.values.toList();
        notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        if (notes.isEmpty) {
          statusMessage = 'No thoughts yet. Sync your device to get started!';
        } else {
          statusMessage = '${notes.length} thought(s)';
        }
      });
      
      await syncFilesWithDatabase();
      
      if (widget.autoTranscribe) {
        await transcribeAllNew();
      }
      
    } catch (e) {
      setState(() {
        statusMessage = 'Error loading thoughts: $e';
      });
    }
  }

  Future<void> syncFilesWithDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      final files = dir.listSync();
      
      final audioFiles = files
          .where((item) => item.path.contains('audio_'))
          .map((item) => item.path.split(Platform.pathSeparator).last)
          .toList();
      
      for (var filename in audioFiles) {
        final exists = notes.any((note) => note.filename == filename);
        
        if (!exists) {
          final timestampStr = filename.replaceAll('audio_', '').replaceAll('.wav', '').replaceAll('.txt', '');
          DateTime timestamp;
          try {
            final ms = int.parse(timestampStr);
            timestamp = DateTime.fromMillisecondsSinceEpoch(ms);
          } catch (e) {
            timestamp = DateTime.now();
          }
          
          final note = AudioNote(
            filename: filename,
            timestamp: timestamp,
            audioFilePath: '${directory.path}/$filename',
          );
          
          await audioBox.add(note);
        }
      }
      
      setState(() {
        notes = audioBox.values.toList();
        notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        statusMessage = '${notes.length} thought(s)';
      });
      
    } catch (e) {
      print('Sync error: $e');
    }
  }

  Future<void> transcribeAllNew() async {
    for (var note in notes) {
      if (!note.isTranscribed && !transcribing.containsKey(note.filename)) {
        await transcribeAudio(note);
      }
    }
  }

  Future<void> transcribeAudio(AudioNote note) async {
    final apiKey = Config.assemblyAiApiKey;
    
    try {
      setState(() {
        transcribing[note.filename] = true;
        statusMessage = 'Transcribing ${note.filename}...';
      });
      
      final audioFile = File(note.audioFilePath ?? '');
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found');
      }
      
      final audioBytes = await audioFile.readAsBytes();
      
      final uploadResponse = await http.post(
        Uri.parse('https://api.assemblyai.com/v2/upload'),
        headers: {
          'authorization': apiKey,
          'content-type': 'application/octet-stream',
        },
        body: audioBytes,
      );
      
      if (uploadResponse.statusCode != 200) {
        throw Exception('Upload failed');
      }
      
      final uploadData = jsonDecode(uploadResponse.body);
      final uploadUrl = uploadData['upload_url'];
      
      final transcriptResponse = await http.post(
        Uri.parse('https://api.assemblyai.com/v2/transcript'),
        headers: {
          'authorization': apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({'audio_url': uploadUrl}),
      );
      
      if (transcriptResponse.statusCode != 200) {
        throw Exception('Transcription request failed');
      }
      
      final transcriptData = jsonDecode(transcriptResponse.body);
      final transcriptId = transcriptData['id'];
      
      String? transcription;
      while (true) {
        await Future.delayed(Duration(seconds: 2));
        
        final pollResponse = await http.get(
          Uri.parse('https://api.assemblyai.com/v2/transcript/$transcriptId'),
          headers: {'authorization': apiKey},
        );
        
        final pollData = jsonDecode(pollResponse.body);
        final status = pollData['status'];
        
        if (status == 'completed') {
          transcription = pollData['text'];
          break;
        } else if (status == 'error') {
          throw Exception('Transcription failed');
        }
      }
      
      note.transcription = transcription ?? 'No transcription available';
      note.isTranscribed = true;
      await note.save();
      
      setState(() {
        transcribing[note.filename] = false;
        statusMessage = '${notes.length} thought(s)';
        notes = audioBox.values.toList();
        notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
      
    } catch (e) {
      note.transcription = 'Error: ${e.toString()}';
      await note.save();
      
      setState(() {
        transcribing[note.filename] = false;
        statusMessage = 'Transcription error';
      });
    }
  }

  String getPreview(AudioNote note) {
    if (transcribing[note.filename] == true) {
      return 'Transcribing...';
    }
    
    if (note.transcription == null || note.transcription!.isEmpty) {
      return note.filename;
    }
    
    if (note.transcription!.length <= 50) {
      return note.transcription!;
    }
    
    return '${note.transcription!.substring(0, 50)}...';
  }

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String formatFullDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at ${hour}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> assignCategory(AudioNote note, String category) async {
    note.category = category;
    await note.save();
    
    setState(() {
      statusMessage = 'Assigned to $category';
      notes = audioBox.values.toList();
      notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> playAudio(AudioNote note) async {
    try {
      if (note.audioFilePath == null) return;
      
      if (currentlyPlaying == note.filename && isPlaying) {
        await audioPlayer.pause();
        setState(() {
          isPlaying = false;
        });
        return;
      }
      
      if (isPlaying) {
        await audioPlayer.stop();
      }
      
      await audioPlayer.play(DeviceFileSource(note.audioFilePath!));
      
      setState(() {
        currentlyPlaying = note.filename;
        isPlaying = true;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  Future<void> deleteNote(AudioNote note) async {
    try {
      if (currentlyPlaying == note.filename) {
        await audioPlayer.stop();
        setState(() {
          isPlaying = false;
          currentlyPlaying = null;
        });
      }
      
      if (note.audioFilePath != null) {
        final file = File(note.audioFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      await note.delete();
      
      setState(() {
        notes = audioBox.values.toList();
        notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        statusMessage = '${notes.length} thought(s)';
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e')),
      );
    }
  }

  void showFullTranscription(AudioNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Full Transcription'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      formatFullDateTime(note.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              SizedBox(height: 8),
              Text(
                note.transcription ?? 'No transcription available',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'check_box':
        return Icons.check_box;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'category':
        return Icons.category;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'book':
        return Icons.book;
      case 'music_note':
        return Icons.music_note;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_hospital':
        return Icons.local_hospital;
      default:
        return Icons.category;
    }
  }

  Icon _getCategoryIconFromCategory(UserCategory category) {
    return Icon(_getIconData(category.iconName), color: Color(category.colorValue));
  }

  Icon _getCategoryIcon(String categoryName) {
    final category = categories.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => categories.isNotEmpty ? categories.first : UserCategory(name: 'Default', iconName: 'category', colorValue: 0xFF2196F3),
    );
    return _getCategoryIconFromCategory(category);
  }

  void showAddCategoryDialog() {
    final nameController = TextEditingController();
    String selectedIcon = 'category';
    int selectedColor = 0xFF2196F3;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                SizedBox(height: 16),
                
                Text('Select Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'shopping_cart', 'check_box', 'lightbulb', 'category',
                    'work', 'home', 'star', 'favorite', 'book', 'music_note',
                    'restaurant', 'local_hospital'
                  ].map((iconName) => GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedIcon = iconName;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedIcon == iconName ? Colors.blue : Colors.grey.shade300,
                          width: selectedIcon == iconName ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getIconData(iconName), color: Color(selectedColor)),
                    ),
                  )).toList(),
                ),
                
                SizedBox(height: 16),
                
                Text('Select Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    0xFFFF9800,
                    0xFF2196F3,
                    0xFFFBC02D,
                    0xFF9C27B0,
                    0xFF4CAF50,
                    0xFFF44336,
                    0xFF00BCD4,
                    0xFFFF5722,
                  ].map((colorValue) => GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = colorValue;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == colorValue ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final newCategory = UserCategory(
                    name: nameController.text,
                    iconName: selectedIcon,
                    colorValue: selectedColor,
                  );
                  
                  await categoryBox.add(newCategory);
                  loadCategories();
                  
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Category "${nameController.text}" added!')),
                  );
                }
              },
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void showManageCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Categories'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final usageCount = notes.where((note) => note.category == category.name).length;
              
              return ListTile(
                leading: _getCategoryIconFromCategory(category),
                title: Text(category.name),
                subtitle: Text('$usageCount thought(s)'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDeleteCategoryConfirmation(category, usageCount);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void showDeleteCategoryConfirmation(UserCategory category, int usageCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: Text(
          usageCount > 0
              ? 'This category is used by $usageCount thought(s). Those thoughts will become uncategorized.'
              : 'Are you sure you want to delete this category?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              for (var note in notes) {
                if (note.category == category.name) {
                  note.category = null;
                  await note.save();
                }
              }
              
              await category.delete();
              loadCategories();
              
              Navigator.pop(context);
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Category deleted')),
              );
              
              setState(() {
                notes = audioBox.values.toList();
                notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              });
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void showThoughtOptions(AudioNote note) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Column(
              children: [
                Text(
                  getPreview(note),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        formatFullDateTime(note.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            if (note.transcription != null && note.transcription!.length > 50)
              ListTile(
                leading: Icon(Icons.text_snippet, color: Colors.blue),
                title: Text('View Full Transcription'),
                onTap: () {
                  Navigator.pop(context);
                  showFullTranscription(note);
                },
              ),

            ListTile(
              leading: Icon(Icons.play_arrow, color: Colors.green),
              title: Text('Play Audio'),
              onTap: () {
                Navigator.pop(context);
                playAudio(note);
              },
            ),

            if (!note.isTranscribed && transcribing[note.filename] != true)
              ListTile(
                leading: Icon(Icons.record_voice_over, color: Colors.orange),
                title: Text('Transcribe'),
                onTap: () {
                  Navigator.pop(context);
                  transcribeAudio(note);
                },
              ),

            Divider(),
            
            Text(
              'Assign to Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            
            SizedBox(height: 8),
            
            ...categories.map((category) => ListTile(
              leading: _getCategoryIconFromCategory(category),
              title: Text(category.name),
              trailing: note.category == category.name 
                  ? Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                Navigator.pop(context);
                assignCategory(note, category.name);
              },
            )).toList(),
            
            Divider(),
            
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showDeleteConfirmation(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void showDeleteConfirmation(AudioNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Thought?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteNote(note);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void showCategoryFilter(String categoryName) {
    final filteredNotes = notes.where((note) => note.category == categoryName).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _getCategoryIcon(categoryName),
            SizedBox(width: 12),
            Text(categoryName),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: filteredNotes.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No thoughts in this category yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    
                    return ListTile(
                      leading: Icon(Icons.audiotrack),
                      title: Text(getPreview(note)),
                      subtitle: Text(formatDateTime(note.timestamp)),
                      onTap: () {
                        Navigator.pop(context);
                        showThoughtOptions(note);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,
      
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Ramble',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...categories.map((category) => Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: _CategoryButton(
                            icon: _getIconData(category.iconName),
                            label: category.name,
                            color: Color(category.colorValue),
                            onPressed: () => showCategoryFilter(category.name),
                          ),
                        )).toList(),
                        
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: IconButton(
                            icon: Icon(Icons.add_circle_outline, color: Colors.blue, size: 32),
                            onPressed: showAddCategoryDialog,
                            tooltip: 'Add Category',
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  TextButton.icon(
                    onPressed: showManageCategoriesDialog,
                    icon: Icon(Icons.settings, size: 16),
                    label: Text('Manage Categories', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic_off, size: 64, color: Colors.grey.shade400),
                          SizedBox(height: 16),
                          Text(
                            'No thoughts yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sync your device to get started',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final isTranscribing = transcribing[note.filename] == true;
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: note.category != null
                                ? _getCategoryIcon(note.category!)
                                : Icon(Icons.audiotrack, color: Colors.grey),
                            title: Text(
                              getPreview(note),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontStyle: isTranscribing ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatDateTime(note.timestamp)),
                                if (note.category != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      note.category!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isTranscribing 
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.more_vert),
                            onTap: () => showThoughtOptions(note),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _CategoryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}