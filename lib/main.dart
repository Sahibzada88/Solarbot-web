import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(ChatBotApp());
}

class ChatBotApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Solarbot',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  String _loadingText = ""; // For animated three dots
  Timer? _dotsTimer; // Timer for animating the three dots

  final String apiUrl = "https://solar-bot-weld.vercel.app/ask"; // Your API URL
  final String userId = "12345"; // Static user ID (adjust as needed)

  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceInput = "";

  @override
  void dispose() {
    _dotsTimer?.cancel();
    super.dispose();
  }

  void _startLoadingAnimation() {
    _loadingText = ".";
    _dotsTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      setState(() {
        _loadingText = _loadingText.length == 3 ? "." : "$_loadingText.";
      });
    });
  }

  void _stopLoadingAnimation() {
    _dotsTimer?.cancel();
    setState(() {
      _loadingText = "";
    });
  }

  Future<void> sendMessage(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": question});
      _isLoading = true;
      _startLoadingAnimation();
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "question": question,
          "stream": false,
          "user_id": userId, // Send the user ID
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String botResponse = "I didn't understand that.";

        // Check the response structure for 'response' field
        if (data is Map && data.containsKey('response')) {
          botResponse = data['response'];
        }

        await _displayTypingEffect(botResponse); // Typewriter effect
      } else {
        await _displayTypingEffect("An error occurred. Please try again.");
      }
    } catch (e) {
      await _displayTypingEffect("Failed to connect to server.");
    } finally {
      _stopLoadingAnimation();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _displayTypingEffect(String response) async {
    const typingDelay = Duration(milliseconds: 10); // Delay per character
    String currentText = "";

    for (int i = 0; i < response.length; i++) {
      currentText += response[i];
      await Future.delayed(typingDelay);
      setState(() {
        if (_messages.isEmpty || _messages.last["role"] != "bot") {
          _messages.add({"role": "bot", "text": currentText});
        } else {
          _messages.last["text"] = currentText;
        }
      });
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("Status: $status"),
      onError: (error) => print("Error: $error"),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _voiceInput = result.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
    if (_voiceInput.isNotEmpty) {
      sendMessage(_voiceInput);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.greenAccent,
        title: Text(
          'Solarbot',
          style: TextStyle(fontSize: 30),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
                  return Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.all(10),
                    child: Text(
                      _loadingText, // Show the animated dots
                      style: TextStyle(fontSize: 50, color: Colors.grey),
                    ),
                  );
                }

                final message = _messages[index];
                final isUser = message["role"] == "user";
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      message["text"] ?? "",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your question here...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.mic),
                  onPressed: _isListening ? _stopListening : _startListening,
                  color: _isListening ? Colors.red : Colors.blue,
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    final question = _controller.text;
                    _controller.clear();
                    sendMessage(question);
                  },
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
