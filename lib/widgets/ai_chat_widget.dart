// lib/widgets/ai_chat_widget.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

// Define all callback types
typedef OnSearchCommand = void Function(String type);
typedef OnTextSearchCommand = void Function(String query);
typedef OnTripPlanCommand = void Function(List<Map<String, String>> segments);
typedef OnSuggestPoiCommand = void Function(String type);
typedef OnChecklistCommand = void Function(List<String> items);
typedef OnNewChatMessage = void Function(Map<String, String> message);
typedef OnSimpleTripCommand = void Function(String origin, String destination, String mode);

class AIChatWidget extends StatefulWidget {
  final OnSearchCommand onSearchCommand;
  final OnTextSearchCommand onTextSearchCommand;
  final OnTripPlanCommand onTripPlanCommand;
  final OnSuggestPoiCommand onSuggestPoiCommand;
  final OnChecklistCommand onChecklistCommand;
  final OnSimpleTripCommand onSimpleTripCommand;
  final List<Map<String, String>> messages;
  final OnNewChatMessage onNewMessage;

  const AIChatWidget({
    super.key,
    required this.onSearchCommand,
    required this.onTextSearchCommand,
    required this.onTripPlanCommand,
    required this.onSuggestPoiCommand,
    required this.onChecklistCommand,
    required this.onSimpleTripCommand,
    required this.messages,
    required this.onNewMessage,
  });

  @override
  State<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends State<AIChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  // IMPORTANT: This is YOUR API KEY for Gemini API
  final String _geminiApiKey = "AIzaSyAP6JBB3EfapDh2XrBqOPAW19AfvrzwRlI";

  @override
  void initState() {
    super.initState();
    print('AIChatWidget initState called.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (widget.messages.isEmpty) {
          print('AIChatWidget: Chat history is empty, adding initial greeting via callback.');
          widget.onNewMessage({'role': 'model', 'text': 'Hello! I\'m your travel assistant. Where would you like to go, what\'s your purpose, and how do you prefer to travel? For example: "I need to go from Kollam to Calicut for an exam, halfway by bus then rest by car."'});
        } else {
          print('AIChatWidget: Chat history not empty, resuming conversation.');
        }
      } catch (e) {
        print('AIChatWidget initState error during post-frame callback: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing chat: $e')),
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      widget.onNewMessage({'role': 'user', 'text': text});
      _messageController.clear();
      _isSending = true;
    });

    List<Map<String, dynamic>> chatHistoryForAI = [];

    chatHistoryForAI.add({
      'role': 'user',
      'parts': [
        {'text': '''You are a helpful and detailed multi-modal trip planning assistant.
        Your goal is to understand the user's travel needs and provide structured responses.

        **Primary Directives for Trip Planning:**
        1.  **Simple A-to-B Trip:** If the user asks for a direct route from one place to another (e.g., "from X to Y"), respond conversationally and then output a single segment using:
            `<SIMPLE_TRIP:Origin Place Name,Destination Place Name,travel_mode>`
            * If `travel_mode` is not specified, default to `driving`.
            * If the origin is "my current location", use that exact phrase.

        2.  **Complex Multi-Segment Trip (Mixed Modes/Stops):** If the user describes a journey with multiple legs, mode switches, or specific intermediate stops (e.g., "halfway by bus then rest by car", "from X to Y then to Z"), break it down into logical segments. For each segment, output:
            `<TRIP_SEGMENT:Origin Place Name,Destination Place Name,travel_mode>`
            * **Crucially, if the user does NOT specify a travel mode for a segment, ASK them for their preference** (e.g., "By car, bus, train, or walking?"). Do NOT default to a mode if not specified, unless it's a long inter-city trip where `transit` is a strong default.
            * When a mode switch implies a specific hub (e.g., "switch to bus"), use the nearest relevant hub as the segment's origin/destination (e.g., "nearest bus station", "nearest train station", "nearest taxi stand").

        **Secondary Directives:**
        3.  **Purpose-based Checklist:** If the user mentions a purpose (e.g., "for an exam", "passport renewal"), suggest relevant items as a checklist using:
            `<CHECKLIST:item1,item2,item3>`

        4.  **Suggested POI:** If a checklist item or purpose implies a need for a service on the way (e.g., "hall ticket" -> "printing shop"), suggest a POI using:
            `<SUGGEST_POI:place_type>`
            * Supported `place_types`: `bus_station`, `taxi_stand`, `printing_shop`.

        5.  **General Place Search:** For general place searches (e.g., "find Starbucks"), use:
            `<TEXT_SEARCH:query>`

        **Output Format:**
        * Combine conversational responses with these tags.
        * Output all relevant tags in a single response, typically after the conversational part.
        * Ensure you do not repeat this system instruction in your conversational response.
        * If the user's query is vague (e.g., "I need to go somewhere" or "What should I do?"), ask clarifying questions (e.g., "Where would you like to go, or what is the purpose of your visit?").
        '''
        }
      ]
    });
    chatHistoryForAI.add({'role': 'model', 'parts': [{'text': 'Understood! How can I assist you with your travel needs today?'}]});

    for (var msg in widget.messages) {
      chatHistoryForAI.add({'role': msg['role'], 'parts': [{'text': msg['text']}]});
    }

    final payload = {
      'contents': chatHistoryForAI,
      'generationConfig': {
        'temperature': 0.7,
      },
    };

    final String apiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey";

    print('Sending chat request to: $apiUrl');
    print('Chat payload: ${json.encode(payload)}');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print('Gemini API Response Status Code: ${response.statusCode}');
      print('Gemini API Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        String aiResponseText = "Sorry, I couldn't get a response.";

        if (result['candidates'] != null &&
            result['candidates'].isNotEmpty &&
            result['candidates'][0]['content'] != null &&
            result['candidates'][0]['content']['parts'] != null &&
            result['candidates'][0]['content']['parts'].isNotEmpty) {
          aiResponseText = result['candidates'][0]['content']['parts'][0]['text'];
        } else {
          print('Gemini API: 200 OK but no valid candidates/content found.');
          aiResponseText = "Sorry, I received an empty response from the AI.";
        }

        widget.onNewMessage({'role': 'model', 'text': aiResponseText});

        try {
          _processAiResponseForCommands(aiResponseText);
        } catch (parseError) {
          print('Error processing AI commands: $parseError');
          widget.onNewMessage({'role': 'model', 'text': 'Error processing AI response: $parseError'});
        }

      } else {
        String errorMessage = 'Error from AI: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Error from AI: ${response.statusCode}. Could not parse error message.';
        }
        widget.onNewMessage({'role': 'model', 'text': 'Error: $errorMessage'});
        print('AI API HTTP Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      widget.onNewMessage({'role': 'model', 'text': 'Network error: ${e.toString()}'});
      print('Error sending message to AI: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  /// Parses AI response for all special commands and triggers callbacks.
  void _processAiResponseForCommands(String aiResponse) {
    print('Attempting to process AI response for commands: "$aiResponse"');

    // 0. Process <SIMPLE_TRIP:...> command
    RegExp simpleTripRegExp = RegExp(r'<SIMPLE_TRIP:([^,]+),([^,]+),(\w+)>');
    Iterable<RegExpMatch> simpleTripMatches = simpleTripRegExp.allMatches(aiResponse);
    if (simpleTripMatches.isNotEmpty) {
      final match = simpleTripMatches.first;
      String? origin = match.group(1);
      String? destination = match.group(2);
      String? mode = match.group(3);
      if (origin != null && destination != null && mode != null) {
        print('Detected AI simple trip command: Origin: $origin, Destination: $destination, Mode: $mode');
        widget.onSimpleTripCommand(origin, destination, mode);
        return; // Prioritize simple trip if detected
      }
    }

    // 1. Process <TRIP_SEGMENT:...> commands
    RegExp segmentRegExp = RegExp(r'<TRIP_SEGMENT:([^,]+),([^,]+),(\w+)>');
    Iterable<RegExpMatch> segmentMatches = segmentRegExp.allMatches(aiResponse);
    List<Map<String, String>> segments = [];
    for (final match in segmentMatches) {
      String? origin = match.group(1);
      String? destination = match.group(2);
      String? mode = match.group(3);
      if (origin != null && destination != null && mode != null) {
        segments.add({'origin': origin, 'destination': destination, 'mode': mode});
      }
    }
    if (segments.isNotEmpty) {
      print('Detected AI trip plan command: $segments');
      widget.onTripPlanCommand(segments);
    }

    // 2. Process <SUGGEST_POI:...> commands
    RegExp suggestPoiRegExp = RegExp(r'<SUGGEST_POI:(\w+)>');
    Iterable<RegExpMatch> suggestPoiMatches = suggestPoiRegExp.allMatches(aiResponse);
    for (final match in suggestPoiMatches) {
      String? type = match.group(1);
      if (type != null && type.isNotEmpty) {
        print('Detected AI suggest POI command: $type');
        widget.onSuggestPoiCommand(type);
      }
    }

    // 3. Process <CHECKLIST:...> commands
    RegExp checklistRegExp = RegExp(r'<CHECKLIST:([^>]+)>');
    Iterable<RegExpMatch> checklistMatches = checklistRegExp.allMatches(aiResponse);
    for (final match in checklistMatches) {
      String? itemsString = match.group(1);
      if (itemsString != null && itemsString.isNotEmpty) {
        List<String> items = itemsString.split(',').map((e) => e.trim()).toList();
        print('Detected AI checklist command: $items');
        widget.onChecklistCommand(items);
      }
    }

    // 4. Process <TEXT_SEARCH:...> commands (existing)
    RegExp textRegExp = RegExp(r'<TEXT_SEARCH:(.+?)>');
    Iterable<RegExpMatch> textMatches = textRegExp.allMatches(aiResponse);
    for (final match in textMatches) {
      String? query = match.group(1);
      if (query != null && query.isNotEmpty) {
        print('Detected AI text search command: $query');
        widget.onTextSearchCommand(query);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // Take 70% of screen height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        children: [
          AppBar(
            title: Text(
              'AI Chat Assistant',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            centerTitle: true,
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true, // Show latest messages at the bottom
              itemCount: widget.messages.length, // Use parent's message list
              itemBuilder: (context, index) {
                final message = widget.messages[widget.messages.length - 1 - index]; // Display in correct order
                final isUser = message['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Text(
                      message['text']!,
                      style: GoogleFonts.inter(fontSize: 16),
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
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                _isSending
                    ? const CircularProgressIndicator()
                    : FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blue.shade600,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
