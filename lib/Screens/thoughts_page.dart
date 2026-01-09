import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';
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
  
  // Audio and file data
  List<String> savedFiles = [];
  Map<String, String> transcriptions = {};
  Map<String, bool> transcribing = {};
  Map<String, String> categories = {};
  Map<String, DateTime> timestamps = {}; // Store file timestamps
  String statusMessage = 'Loading thoughts...';
  
  final audioPlayer = AudioPlayer();
  String? currentlyPlaying;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    loadSavedFiles();
    
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

  // LOAD ALL SAVED FILES
  Future<void> loadSavedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      final files = dir.listSync();
      
      setState(() {
        savedFiles = files
            .where((item) => item.path.contains('audio_'))
            .map((item) => item.path.split(Platform.pathSeparator).last)
            .toList();
        
        // Extract timestamps from filenames and store them
        for (var filename in savedFiles) {
          final timestampStr = filename.replaceAll('audio_', '').replaceAll('.wav', '').replaceAll('.txt', '');
          try {
            final timestamp = int.parse(timestampStr);
            timestamps[filename] = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } catch (e) {
            timestamps[filename] = DateTime.now();
          }
        }
        
        // Sort by timestamp (newest first)
        savedFiles.sort((a, b) {
          final timeA = timestamps[a] ?? DateTime.now();
          final timeB = timestamps[b] ?? DateTime.now();
          return timeB.compareTo(timeA);
        });
        
        if (savedFiles.isEmpty) {
          statusMessage = 'No thoughts yet. Sync your device to get started!';
        } else {
          statusMessage = '${savedFiles.length} thought(s)';
        }
      });
      
      // Auto-transcribe if requested (from sync button)
      if (widget.autoTranscribe && savedFiles.isNotEmpty) {
        await transcribeAllNew();
      }
      
    } catch (e) {
      setState(() {
        statusMessage = 'Error loading files: $e';
      });
    }
  }

  // AUTO-TRANSCRIBE NEW FILES
  Future<void> transcribeAllNew() async {
    for (var filename in savedFiles) {
      if (!transcriptions.containsKey(filename) && !transcribing.containsKey(filename)) {
        await transcribeAudio(filename);
      }
    }
  }

  // TRANSCRIBE AUDIO FILE
  Future<void> transcribeAudio(String filename) async {
    final apiKey = Config.assemblyAiApiKey;
    
    try {
      setState(() {
        transcribing[filename] = true;
        statusMessage = 'Transcribing $filename...';
      });
      
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final audioFile = File(filePath);
      final audioBytes = await audioFile.readAsBytes();
      
      // Step 1: Upload the audio file
      final uploadResponse = await http.post(
        Uri.parse('https://api.assemblyai.com/v2/upload'),
        headers: {
          'authorization': apiKey,
          'content-type': 'application/octet-stream',
        },
        body: audioBytes,
      );
      
      if (uploadResponse.statusCode != 200) {
        throw Exception('Upload failed: ${uploadResponse.body}');
      }
      
      final uploadData = jsonDecode(uploadResponse.body);
      final uploadUrl = uploadData['upload_url'];
      
      // Step 2: Request transcription
      final transcriptResponse = await http.post(
        Uri.parse('https://api.assemblyai.com/v2/transcript'),
        headers: {
          'authorization': apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'audio_url': uploadUrl,
        }),
      );
      
      if (transcriptResponse.statusCode != 200) {
        throw Exception('Transcription request failed: ${transcriptResponse.body}');
      }
      
      final transcriptData = jsonDecode(transcriptResponse.body);
      final transcriptId = transcriptData['id'];
      
      // Step 3: Poll for completion
      String? transcription;
      while (true) {
        await Future.delayed(Duration(seconds: 2));
        
        final pollResponse = await http.get(
          Uri.parse('https://api.assemblyai.com/v2/transcript/$transcriptId'),
          headers: {
            'authorization': apiKey,
          },
        );
        
        final pollData = jsonDecode(pollResponse.body);
        final status = pollData['status'];
        
        if (status == 'completed') {
          transcription = pollData['text'];
          break;
        } else if (status == 'error') {
          throw Exception('Transcription failed: ${pollData['error']}');
        }
      }
      
      setState(() {
        transcriptions[filename] = transcription ?? 'No transcription available';
        transcribing[filename] = false;
        statusMessage = '${savedFiles.length} thought(s)';
      });
      
    } catch (e) {
      setState(() {
        transcriptions[filename] = 'Error: ${e.toString()}';
        transcribing[filename] = false;
        statusMessage = 'Transcription error';
      });
    }
  }

  // GET PREVIEW (first 50 chars of transcription)
  String getPreview(String filename) {
    if (transcribing[filename] == true) {
      return 'Transcribing...';
    }
    
    final transcription = transcriptions[filename];
    if (transcription == null || transcription.isEmpty) {
      return filename;
    }
    
    if (transcription.length <= 50) {
      return transcription;
    }
    
    return '${transcription.substring(0, 50)}...';
  }

  // FORMAT DATE/TIME
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
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at ${hour}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  // ASSIGN CATEGORY
  void assignCategory(String filename, String category) {
    setState(() {
      categories[filename] = category;
      statusMessage = 'Assigned to $category';
    });
  }

  // PLAY AUDIO
  Future<void> playAudio(String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      
      if (currentlyPlaying == filename && isPlaying) {
        await audioPlayer.pause();
        setState(() {
          isPlaying = false;
        });
        return;
      }
      
      if (isPlaying) {
        await audioPlayer.stop();
      }
      
      await audioPlayer.play(DeviceFileSource(filePath));
      
      setState(() {
        currentlyPlaying = filename;
        isPlaying = true;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  // DELETE FILE
  Future<void> deleteFile(String filename) async {
    try {
      if (currentlyPlaying == filename) {
        await audioPlayer.stop();
        setState(() {
          isPlaying = false;
          currentlyPlaying = null;
        });
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.delete();
      
      transcriptions.remove(filename);
      transcribing.remove(filename);
      categories.remove(filename);
      timestamps.remove(filename);
      
      setState(() {
        statusMessage = 'Deleted thought';
      });
      
      loadSavedFiles();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e')),
      );
    }
  }

  // SHOW FULL TRANSCRIPTION
  void showFullTranscription(String filename) {
    final transcription = transcriptions[filename];
    final timestamp = timestamps[filename];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Full Transcription'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (timestamp != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        formatFullDateTime(timestamp),
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
                transcription ?? 'No transcription available',
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

  // SHOW THOUGHT OPTIONS MENU
  void showThoughtOptions(String filename) {
    final timestamp = timestamps[filename];
    
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
            
            // Preview and timestamp
            Column(
              children: [
                Text(
                  getPreview(filename),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (timestamp != null)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          formatFullDateTime(timestamp),
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
            
            // View Full Transcription
            if (transcriptions[filename] != null && transcriptions[filename]!.length > 50)
              ListTile(
                leading: Icon(Icons.text_snippet, color: Colors.blue),
                title: Text('View Full Transcription'),
                onTap: () {
                  Navigator.pop(context);
                  showFullTranscription(filename);
                },
              ),
            
            // Play Audio
            ListTile(
              leading: Icon(Icons.play_arrow, color: Colors.green),
              title: Text('Play Audio'),
              onTap: () {
                Navigator.pop(context);
                playAudio(filename);
              },
            ),
            
            Divider(),
            
            // Category options
            Text(
              'Assign to Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            
            SizedBox(height: 8),
            
            ListTile(
              leading: Icon(Icons.shopping_cart, color: Colors.orange),
              title: Text('Shopping List'),
              trailing: categories[filename] == 'Shopping List' 
                  ? Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                Navigator.pop(context);
                assignCategory(filename, 'Shopping List');
              },
            ),
            
            ListTile(
              leading: Icon(Icons.check_box, color: Colors.blue),
              title: Text('To Do List'),
              trailing: categories[filename] == 'To Do List' 
                  ? Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                Navigator.pop(context);
                assignCategory(filename, 'To Do List');
              },
            ),
            
            ListTile(
              leading: Icon(Icons.lightbulb, color: Colors.yellow.shade700),
              title: Text('Ideas'),
              trailing: categories[filename] == 'Ideas' 
                  ? Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                Navigator.pop(context);
                assignCategory(filename, 'Ideas');
              },
            ),
            
            ListTile(
              leading: Icon(Icons.category, color: Colors.purple),
              title: Text('Miscellaneous'),
              trailing: categories[filename] == 'Miscellaneous' 
                  ? Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                Navigator.pop(context);
                assignCategory(filename, 'Miscellaneous');
              },
            ),
            
            Divider(),
            
            // Delete
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showDeleteConfirmation(filename);
              },
            ),
          ],
        ),
      ),
    );
  }

  // SHOW DELETE CONFIRMATION
  void showDeleteConfirmation(String filename) {
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
              deleteFile(filename);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // SHOW CATEGORY FILTER
  void showCategoryFilter(String category) {
    final filteredFiles = savedFiles
        .where((file) => categories[file] == category)
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _getCategoryIcon(category),
            SizedBox(width: 12),
            Text(category),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: filteredFiles.isEmpty
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
                  itemCount: filteredFiles.length,
                  itemBuilder: (context, index) {
                    final file = filteredFiles[index];
                    final timestamp = timestamps[file];
                    
                    return ListTile(
                      leading: Icon(Icons.audiotrack),
                      title: Text(getPreview(file)),
                      subtitle: timestamp != null
                          ? Text(formatDateTime(timestamp))
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        showThoughtOptions(file);
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

  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'Shopping List':
        return Icon(Icons.shopping_cart, color: Colors.orange);
      case 'To Do List':
        return Icon(Icons.check_box, color: Colors.blue);
      case 'Ideas':
        return Icon(Icons.lightbulb, color: Colors.yellow.shade700);
      case 'Miscellaneous':
        return Icon(Icons.category, color: Colors.purple);
      default:
        return Icon(Icons.category);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,
      
      body: SafeArea(
        child: Column(
          children: [
            // TOP BANNER
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
            
            // CATEGORY FILTER BUTTONS
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _CategoryButton(
                      icon: Icons.shopping_cart,
                      label: 'Shopping',
                      color: Colors.orange,
                      onPressed: () => showCategoryFilter('Shopping List'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _CategoryButton(
                      icon: Icons.check_box,
                      label: 'To Do',
                      color: Colors.blue,
                      onPressed: () => showCategoryFilter('To Do List'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _CategoryButton(
                      icon: Icons.lightbulb,
                      label: 'Ideas',
                      color: Colors.yellow.shade700,
                      onPressed: () => showCategoryFilter('Ideas'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _CategoryButton(
                      icon: Icons.category,
                      label: 'Misc',
                      color: Colors.purple,
                      onPressed: () => showCategoryFilter('Miscellaneous'),
                    ),
                  ),
                ],
              ),
            ),
            
            // Status message
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
            
            // ALL THOUGHTS LIST
            Expanded(
              child: savedFiles.isEmpty
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
                      itemCount: savedFiles.length,
                      itemBuilder: (context, index) {
                        final filename = savedFiles[index];
                        final category = categories[filename];
                        final timestamp = timestamps[filename];
                        final isTranscribing = transcribing[filename] == true;
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: category != null
                                ? _getCategoryIcon(category)
                                : Icon(Icons.audiotrack, color: Colors.grey),
                            title: Text(
                              getPreview(filename),
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
                                if (timestamp != null)
                                  Text(formatDateTime(timestamp)),
                                if (category != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      category,
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
                            onTap: () => showThoughtOptions(filename),
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

// CATEGORY BUTTON WIDGET
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
        padding: EdgeInsets.symmetric(vertical: 12),
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