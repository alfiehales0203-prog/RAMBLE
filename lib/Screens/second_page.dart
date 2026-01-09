import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'third_page.dart';
import '../config.dart';

class SecondPage extends StatefulWidget {
  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  // FILE STORAGE VARIABLES
  List<String> savedFiles = [];
  Map<String, String> transcriptions = {};  // filename -> transcription text
  Map<String, bool> transcribing = {};  // filename -> is currently transcribing
  String statusMessage = 'No files saved yet';
  
  // AUDIO PLAYER
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

  // SAVE A MOCK AUDIO FILE
  Future<void> saveMockAudioFile() async {
    try {
      final audioData = await rootBundle.load('assets/sample.wav');
      final bytes = audioData.buffer.asUint8List();
      
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/audio_$timestamp.wav';
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      setState(() {
        statusMessage = 'Audio saved: audio_$timestamp.wav';
      });
      
      loadSavedFiles();
      
    } catch (e) {
      setState(() {
        statusMessage = 'Error saving file: $e';
      });
    }
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
        
        if (savedFiles.isEmpty) {
          statusMessage = 'No files saved yet';
        } else {
          statusMessage = 'Found ${savedFiles.length} file(s)';
        }
      });
      
    } catch (e) {
      setState(() {
        statusMessage = 'Error loading files: $e';
      });
    }
  }

  // TRANSCRIBE AUDIO FILE WITH ASSEMBLY.AI
  Future<void> transcribeAudio(String filename) async {
    final apiKey = Config.assemblyAiApiKey;
    try {
      setState(() {
        transcribing[filename] = true;
        statusMessage = 'Uploading $filename to Assembly.ai...';
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
      
      setState(() {
        statusMessage = 'Processing transcription...';
      });
      
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
        
        setState(() {
          statusMessage = 'Transcribing... ($status)';
        });
      }
      
      setState(() {
        transcriptions[filename] = transcription ?? 'No transcription available';
        transcribing[filename] = false;
        statusMessage = 'Transcription complete for $filename!';
      });
      
    } catch (e) {
      setState(() {
        transcriptions[filename] = 'Error: ${e.toString()}';
        transcribing[filename] = false;
        statusMessage = 'Transcription error: $e';
      });
    }
  }

  // PLAY AUDIO FILE
  Future<void> playAudio(String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      
      if (currentlyPlaying == filename && isPlaying) {
        await audioPlayer.pause();
        setState(() {
          isPlaying = false;
          statusMessage = 'Paused: $filename';
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
        statusMessage = 'Playing: $filename';
      });
      
    } catch (e) {
      setState(() {
        statusMessage = 'Error playing file: $e';
        isPlaying = false;
      });
    }
  }

  // STOP PLAYBACK
  Future<void> stopAudio() async {
    await audioPlayer.stop();
    setState(() {
      isPlaying = false;
      currentlyPlaying = null;
      statusMessage = 'Playback stopped';
    });
  }

  // DELETE FILE
  Future<void> deleteFile(String filename) async {
    try {
      if (currentlyPlaying == filename) {
        await stopAudio();
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.delete();
      
      // Remove transcription data
      transcriptions.remove(filename);
      transcribing.remove(filename);
      
      setState(() {
        statusMessage = 'Deleted: $filename';
      });
      
      loadSavedFiles();
      
    } catch (e) {
      setState(() {
        statusMessage = 'Error deleting file: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Manager'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NAVIGATION BUTTONS
            Text(
              'Audio Transcription App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('← Home'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ThirdPage()),
                      );
                    },
                    child: Text('Next →'),
                  ),
                ),
              ],
            ),
            
            Divider(height: 32, thickness: 2),
            
            // Status message
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusMessage,
                style: TextStyle(fontSize: 14),
              ),
            ),
            
            SizedBox(height: 12),
            
            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: saveMockAudioFile,
                    icon: Icon(Icons.add),
                    label: Text('Save Audio'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPlaying ? stopAudio : null,
                    icon: Icon(Icons.stop),
                    label: Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Text(
              'Audio Files (${savedFiles.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 8),
            
            // File list
            Expanded(
              child: savedFiles.isEmpty
                  ? Center(
                      child: Text('No files yet. Save one to get started!'),
                    )
                  : ListView.builder(
                      itemCount: savedFiles.length,
                      itemBuilder: (context, index) {
                        final filename = savedFiles[index];
                        final isCurrentlyPlaying = currentlyPlaying == filename && isPlaying;
                        final hasTranscription = transcriptions.containsKey(filename);
                        final isTranscribing = transcribing[filename] ?? false;
                        
                        return Card(
                          color: isCurrentlyPlaying ? Colors.blue.shade50 : null,
                          margin: EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Filename and controls
                                Row(
                                  children: [
                                    Icon(
                                      isCurrentlyPlaying ? Icons.volume_up : Icons.audiotrack,
                                      color: isCurrentlyPlaying ? Colors.blue : Colors.grey,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        filename,
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.play_arrow, color: Colors.green),
                                      onPressed: () => playAudio(filename),
                                      tooltip: 'Play',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.text_fields, color: Colors.blue),
                                      onPressed: isTranscribing ? null : () => transcribeAudio(filename),
                                      tooltip: 'Transcribe',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => deleteFile(filename),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                                
                                // Transcription area
                                if (isTranscribing)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Transcribing...',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                if (hasTranscription && !isTranscribing)
                                  Container(
                                    margin: EdgeInsets.only(top: 8),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.text_snippet, size: 16, color: Colors.blue),
                                            SizedBox(width: 4),
                                            Text(
                                              'Transcription:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          transcriptions[filename]!,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                if (!hasTranscription && !isTranscribing)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Tap 📝 to transcribe',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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