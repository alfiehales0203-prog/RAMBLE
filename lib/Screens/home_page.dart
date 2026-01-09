import 'package:flutter/material.dart';
import 'package:ramble/screens/thoughts_page.dart';
import 'thoughts_page.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Mock data for recent thoughts
  List<Map<String, String>> recentThoughts = [
    {
      'title': 'Meeting Notes',
      'preview': 'Discussed project timeline and deliverables...',
      'time': '2 hours ago'
    },
    {
      'title': 'Grocery List',
      'preview': 'Milk, eggs, bread, coffee...',
      'time': '5 hours ago'
    },
  ];

  void _syncAudio() async {
    // Show syncing message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Syncing audio files...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Navigate to thoughts page which will handle the transcription
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ThoughtsPage(autoTranscribe: true)),
    );
    
    // Refresh recent thoughts when returning
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      
      // DRAWER MENU (slides from left)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ramble',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Voice Notes & Transcription',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.library_books),
              title: Text('All Thoughts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ThoughtsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.bluetooth),
              title: Text('Bluetooth Settings'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bluetooth settings coming soon!')),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settings coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.help_outline),
              title: Text('Help & Tutorial'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Help coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
      
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
                  // Home Icon (left)
                  IconButton(
                    icon: Icon(Icons.home, color: Colors.white, size: 28),
                    onPressed: () {
                      // Already on home, could show a message or do nothing
                    },
                  ),
                  
                  // App Title (center)
                  Text(
                    'Ramble',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  // Menu Icon (right)
                  IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                ],
              ),
            ),
            
            // MAIN CONTENT
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Spacer(flex: 2),
                  
                  // BIG SYNC BUTTON
                  GestureDetector(
                    onTap: _syncAudio,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200,
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sync,
                            size: 64,
                            color: Colors.white,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'SYNC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  Text(
                    'Tap to sync your voice notes',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  
                  Spacer(flex: 1),
                  
                  // RECENT THOUGHTS SECTION
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Thoughts',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ThoughtsPage()),
                                );
                              },
                              child: Text('View All →'),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Recent thoughts preview
                        ...recentThoughts.map((thought) => Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(Icons.mic, color: Colors.blue),
                            ),
                            title: Text(
                              thought['title']!,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  thought['preview']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  thought['time']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ThoughtsPage()),
                              );
                            },
                          ),
                        )).toList(),
                        
                        if (recentThoughts.isEmpty)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.mic_off,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No thoughts yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Sync your device to get started',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  Spacer(flex: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}