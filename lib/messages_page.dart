import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagesPage extends StatefulWidget {
  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  List<Message> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // Simüle edilmiş mesajlar
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      _messages = [
        Message(
          id: '1',
          senderName: 'Ahmet Yılmaz',
          senderEmail: 'ahmet@example.com',
          lastMessage: 'Merhaba, ilanınızla ilgileniyorum',
          timestamp: DateTime.now().subtract(Duration(minutes: 30)),
          unread: true,
          adTitle: 'Golden Retriever Max',
        ),
        Message(
          id: '2',
          senderName: 'Ayşe Demir',
          senderEmail: 'ayse@example.com',
          lastMessage: 'Kedi hala müsait mi?',
          timestamp: DateTime.now().subtract(Duration(hours: 2)),
          unread: false,
          adTitle: 'British Shorthair Bella',
        ),
        Message(
          id: '3',
          senderName: 'Mehmet Kaya',
          senderEmail: 'mehmet@example.com',
          lastMessage: 'Randevu için uygun musunuz?',
          timestamp: DateTime.now().subtract(Duration(days: 1)),
          unread: false,
          adTitle: 'Çiftleştirme İlanı',
        ),
        Message(
          id: '4',
          senderName: 'PetMate Destek',
          senderEmail: 'destek@petmate.com',
          lastMessage: 'İlanınız onaylandı!',
          timestamp: DateTime.now().subtract(Duration(days: 2)),
          unread: true,
          adTitle: 'Sistem Mesajı',
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mesajlar'),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // TODO: Mesaj arama
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Mesaj ayarları
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _messages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'Henüz mesajınız yok',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'İlanlarınıza gelen mesajlar burada görünecek',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          return _buildMessageItem(_messages[index]);
        },
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: message.unread ? Colors.blue[100] : Colors.grey[200],
          child: Text(
            message.senderName.substring(0, 1),
            style: TextStyle(
              color: message.unread ? Colors.blue[800] : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontWeight: message.unread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (message.unread)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: message.unread ? Colors.black : Colors.grey[600],
              ),
            ),
            SizedBox(height: 2),
            Text(
              message.adTitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (message.timestamp.difference(DateTime.now()).inDays.abs() == 0)
              Text(
                'Bugün',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                ),
              ),
          ],
        ),
        onTap: () {
          _showMessageDetails(message);
        },
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showMessageDetails(Message message) {
    setState(() {
      message.unread = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Mesaj Detayı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 16),

            // Mesaj Başlığı
            Text(
              message.adTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 8),

            // Gönderen Bilgisi
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(message.senderName.substring(0, 1)),
                ),
                title: Text(message.senderName),
                subtitle: Text(message.senderEmail),
                trailing: IconButton(
                  icon: Icon(Icons.phone),
                  onPressed: () {
                    // TODO: Telefon arama
                  },
                ),
              ),
            ),
            SizedBox(height: 16),

            // Mesaj İçeriği
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mesaj:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(message.lastMessage),
                        SizedBox(height: 16),
                        Text(
                          'Tarih: ${message.timestamp.day}/${message.timestamp.month}/${message.timestamp.year} ${message.timestamp.hour}:${message.timestamp.minute}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Cevaplama
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue[800],
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      // TODO: Mesaj gönderme
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Message {
  String id;
  String senderName;
  String senderEmail;
  String lastMessage;
  DateTime timestamp;
  bool unread;
  String adTitle;

  Message({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.lastMessage,
    required this.timestamp,
    required this.unread,
    required this.adTitle,
  });
}