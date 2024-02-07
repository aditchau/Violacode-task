import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:contacts_service/contacts_service.dart';

void main() {
  runApp(MyApp());
}

class ContactCallHistory {
  final Contact contact;
  final List<CallLogEntry> callHistory;

  ContactCallHistory({required this.contact, required this.callHistory});
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Log Access App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: CallLogScreen(),
    );
  }
}

class CallLogScreen extends StatefulWidget {
  @override
  _CallLogScreenState createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  List<CallLogEntry> _allCallLogs = [];
  List<CallLogEntry> _filteredCallLogs = [];
  List<Contact> _contacts = [];
  TextEditingController _searchController = TextEditingController();
  TextEditingController _dialerController = TextEditingController();
  late FocusNode _searchFocus;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Log Access App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Call Log'),
          actions: [
            IconButton(
              icon: Icon(Icons.lightbulb),
              onPressed: () {
                _toggleTheme();
              },
            ),
            IconButton(
              icon: Icon(Icons.contacts),
              onPressed: () {
                _showContactList();
              },
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
      child: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.portrait
              ? _buildPortraitLayout()
              : _buildLandscapeLayout();
        },
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _filterCallLogs(value);
            },
          ),
        ),
        if (_searchController.text.isEmpty)
          Expanded(
            child: _buildCallLogList(),
          ),
        if (_searchController.text.isEmpty)
          _buildDialerPad(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Flexible(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _filterCallLogs(value);
              },
            ),
          ),
        ),
        Flexible(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: _buildCallLogList(),
              ),
              if (_searchController.text.isEmpty)
                _buildDialerPad(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDialerPad() {
    return DialerPad(
      phoneNumberController: _dialerController,
      onNumberPressed: (number) {
        _onNumberPressed(number);
      },
      onBackspacePressed: _onBackspacePressed,
      onCallPressed: _onCallPressed,
      isDialerVisible: !_searchFocus.hasFocus,
    );
  }

  Future<void> _init() async {
    await _requestPermissions();
    await Future.wait([_getCallLogs(), _getContacts()]);
  }
  Future<void> _getContacts() async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    setState(() {
      _contacts = contacts.toList();
    });
  }
  Future<void> _requestPermissions() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      await Permission.contacts.request();
    }

    status = await Permission.phone.status;
    if (!status.isGranted) {
      await Permission.phone.request();
    }
  }

  Future<void> _getCallLogs() async {
    var callLogs = await CallLog.get();
    setState(() {
      _allCallLogs = callLogs.toList();
      _filteredCallLogs = _allCallLogs;
    });
  }

  Future<List<ContactCallHistory>> _getContactSuggestions(String searchTerm) async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    List<ContactCallHistory> contactHistories = [];

    for (var contact in contacts) {
      List<CallLogEntry> callHistory = [];

      if (contact.phones?.isNotEmpty == true) {
        callHistory = _allCallLogs
            .where((callLog) =>
        callLog.number == contact.phones!.first.value ||
            callLog.name == contact.displayName)
            .toList();
      }

      if (callHistory.isNotEmpty) {
        contactHistories.add(ContactCallHistory(
            contact: contact, callHistory: callHistory));
      }
    }


    return contactHistories;
  }


  void _onNumberPressed(String number) {
    setState(() {
      _dialerController.text = number;
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_dialerController.text.isNotEmpty) {
        _dialerController.text =
            _dialerController.text.substring(0, _dialerController.text.length - 1);
      }
    });
  }

  void _onCallPressed() {
    // Handle dialing logic here
  }

  Widget _buildCallLogList() {
    return ListView.builder(
      itemCount: _filteredCallLogs.length,
      itemBuilder: (context, index) {
        var callLog = _filteredCallLogs[index];
        return ListTile(
          title: Text(callLog.name ?? 'Unknown'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getCallTypeIcon(callLog.callType!),
                  SizedBox(width: 8),
                  Text(
                    'Number: ${callLog.number ?? 'N/A'}',
                  ),
                ],
              ),
              Text(
                'Duration: ${_formatDuration(callLog.duration!)}',
              ),
              Text(
                'Timestamp: ${DateFormat.yMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(callLog.timestamp ?? 0))}',
              ),
            ],
          ),
          onTap: () {
            _showCallLogDetails(callLog);
          },
        );
      },
    );
  }

  Widget _getCallTypeIcon(CallType callType) {
    IconData icon;
    switch (callType) {
      case CallType.incoming:
        icon = Icons.call_received;
        break;
      case CallType.outgoing:
        icon = Icons.call_made;
        break;
      case CallType.missed:
        icon = Icons.call_missed;
        break;
      case CallType.rejected:
        icon = Icons.call_end;
        break;
      default:
        icon = Icons.call;
        break;
    }

    return Icon(icon, color: _getIconColor(callType));
  }

  Color _getIconColor(CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
        return Colors.red;
      case CallType.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _filterCallLogs(String searchTerm) async {
    print('Search Term: $searchTerm');
    if (searchTerm.isEmpty) {
      setState(() {
        _filteredCallLogs = _allCallLogs;
      });
    } else {
      List<ContactCallHistory> contactHistories = await _getContactSuggestions(searchTerm);

      setState(() {
        _filteredCallLogs = contactHistories
            .expand((contactHistory) => contactHistory.callHistory)
            .toList();
      });
    }
    print('Filtered Call Logs: $_filteredCallLogs');
  }




  void _toggleTheme() {
    ThemeMode newThemeMode =
    _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newThemeMode);
  }

  void setThemeMode(ThemeMode newThemeMode) {
    setState(() {
      _themeMode = newThemeMode;
    });
  }

  void _showCallLogDetails(CallLogEntry callLog) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Call Log Details'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${callLog.name ?? 'Unknown'}'),
              Text('Number: ${callLog.number ?? 'N/A'}'),
              Text('Type: ${_getCallType(callLog.callType!)}'),
              Text('Duration: ${_formatDuration(callLog.duration!)}'),
              Text(
                'Timestamp: ${callLog.timestamp != null ? DateFormat.yMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(callLog.timestamp!)) : 'Unknown'}',
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _getCallType(CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.rejected:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  String _formatDuration(int seconds) {
    Duration duration = Duration(seconds: seconds);
    String formattedDuration = duration.toString().split('.').first.padLeft(8, '0');
    return formattedDuration;
  }

  void _showContactList() async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactListScreen(contacts: contacts.toList(), themeMode: _themeMode),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
    _searchFocus = FocusNode();
  }
}

class DialerPad extends StatelessWidget {
  final TextEditingController phoneNumberController;
  final Function(String) onNumberPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback onCallPressed;
  final bool isDialerVisible;

  DialerPad({
    required this.phoneNumberController,
    required this.onNumberPressed,
    required this.onBackspacePressed,
    required this.onCallPressed,
    required this.isDialerVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (isDialerVisible) _buildPhoneNumberArea(),
          SizedBox(height: 16.0),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.backspace),
                onPressed: () {
                  onBackspacePressed();
                },
              ),
              SizedBox(width: 16.0),
              ElevatedButton(
                onPressed: () {
                  onCallPressed();
                },
                child: Text('Dial'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneNumberArea() {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone),
          SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: phoneNumberController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: InputBorder.none,
              ),
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                onNumberPressed(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialerButton(String digit) {
    return TextButton(
      onPressed: () {
        phoneNumberController.text += digit;
        onNumberPressed(phoneNumberController.text);
      },
      child: Text(digit),
    );
  }
}

class ContactListScreen extends StatelessWidget {
  final List<Contact> contacts;
  final ThemeMode themeMode;

  ContactListScreen({required this.contacts, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Contact List'),
        ),
        body: _buildContactList(),
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        var contact = contacts[index];
        return ListTile(
          title: Text(contact.displayName ?? 'Unknown'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.phones != null && contact.phones!.isNotEmpty)
                Text('Phone: ${contact.phones!.first.value}'),
              if (contact.emails != null && contact.emails!.isNotEmpty)
                Text('Email: ${contact.emails!.first.value}'),
            ],
          ),
        );
      },
    );
  }
}
