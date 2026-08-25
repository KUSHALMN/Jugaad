import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';

// Model definitions for Chat
class ChatSession {
  final String id; // jobId
  final String name;
  final String service;
  final Color avatarColor;
  final bool isOnline;
  int unreadCount;
  final List<ChatMessage> messages;
  final String otherUserId;

  ChatSession({
    required this.id,
    required this.name,
    required this.service,
    required this.avatarColor,
    this.isOnline = true,
    this.unreadCount = 0,
    required this.messages,
    required this.otherUserId,
  });

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? mediaUrl;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.mediaUrl,
    this.readAt,
  });
}

class ChatScreen extends StatefulWidget {
  final String? jobId;

  const ChatScreen({super.key, this.jobId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  ChatSession? _currentSession;
  bool _isLoading = true;

  // Real data state
  List<ChatSession> _sessions = [];
  final Map<String, Map<String, dynamic>> _userCache = {};
  
  // Subscriptions for real-time updates
  StreamSubscription? _jobsSubscription;
  StreamSubscription? _messagesSubscription;
  RealtimeChannel? _allMessagesChannel;
  RealtimeChannel? _usersChannel;
  RealtimeChannel? _typingChannel;

  bool _otherUserIsTyping = false;
  Timer? _typingTimer;
  bool _isMeTyping = false;

  String? _currentUid;
  bool _isWorker = false;

  @override
  void initState() {
    super.initState();
    _currentUid = AuthService().currentUser?.uid;
    _isWorker = AuthService().userRole == 'worker';
    
    // Fallback path check if auth role is not populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final path = GoRouterState.of(context).uri.path;
        if (path.contains('/worker/')) {
          setState(() {
            _isWorker = true;
          });
        }
        _initRealtimeInbox();
      }
    });
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jobId != oldWidget.jobId) {
      _loadCurrentSession();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _jobsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _allMessagesChannel?.unsubscribe();
    _usersChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _typingTimer?.cancel();
    if (_isMeTyping) {
      _updateTypingStatus(false);
    }
    super.dispose();
  }

  void _initRealtimeInbox() {
    if (_currentUid == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _jobsSubscription?.cancel();
    
    // Stream jobs for the user
    final jobsQuery = SupabaseConfig.client.from('jobs').stream(primaryKey: ['id']);
    final filteredQuery = _isWorker 
        ? jobsQuery.eq('worker_id', _currentUid!)
        : jobsQuery.eq('employer_id', _currentUid!);

    _jobsSubscription = filteredQuery.listen((List<Map<String, dynamic>> jobs) async {
      if (!mounted) return;

      // Filter to jobs that have a worker assigned
      final activeJobs = jobs.where((j) => j['worker_id'] != null).toList();
      
      // Load user details cache for all other participants
      final requiredUserIds = activeJobs.map((j) {
        return _isWorker ? (j['employer_id'] as String) : (j['worker_id'] as String);
      }).toSet().toList();

      if (requiredUserIds.isNotEmpty) {
        final missingIds = requiredUserIds.where((id) => !_userCache.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          try {
            final usersData = await SupabaseConfig.client
                .from('users')
                .select()
                .inFilter('id', missingIds);
            
            for (final u in usersData) {
              _userCache[u['id']] = u;
            }
          } catch (e) {
            print('[ChatScreen] Error caching users: $e');
          }
        }
      }

      // Fetch last messages for all active jobs
      final List<ChatSession> newSessions = [];
      for (final job in activeJobs) {
        final jobId = job['id'] as String;
        final otherUserId = _isWorker ? (job['employer_id'] as String) : (job['worker_id'] as String);
        final otherUser = _userCache[otherUserId] ?? {};
        final otherName = otherUser['name'] as String? ?? 'Jugaad Expert';
        final isOnline = otherUser['is_available'] as bool? ?? otherUser['is_online'] as bool? ?? false;
        
        final skill = job['skill_required'] as String? ?? 'Service';
        final avatarColor = _getServiceColor(skill);

        // Fetch messages for this job
        List<ChatMessage> chatMsgs = [];
        try {
          final msgsData = await SupabaseConfig.client
              .from('messages')
              .select()
              .eq('job_id', jobId)
              .order('created_at', ascending: true);

          chatMsgs = msgsData.map<ChatMessage>((m) {
            return ChatMessage(
              id: m['id'] as String,
              text: m['text'] as String? ?? '',
              isMe: m['sender_id'] == _currentUid,
              timestamp: DateTime.parse(m['created_at'] as String).toLocal(),
              readAt: m['read_at'] != null ? DateTime.parse(m['read_at'] as String).toLocal() : null,
            );
          }).toList();
        } catch (e) {
          print('[ChatScreen] Error loading messages for job $jobId: $e');
        }

        newSessions.add(ChatSession(
          id: jobId,
          name: otherName,
          service: skill,
          avatarColor: avatarColor,
          isOnline: isOnline,
          unreadCount: 0,
          messages: chatMsgs,
          otherUserId: otherUserId,
        ));
      }

      if (mounted) {
        setState(() {
          _sessions = newSessions;
          _isLoading = false;
        });
        _loadCurrentSession();
      }
    }, onError: (err) {
      print('[ChatScreen] Jobs stream error: $err');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // Subscribe to messages table realtime changes to reload inbox
    _allMessagesChannel?.unsubscribe();
    _allMessagesChannel = SupabaseConfig.client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            _initRealtimeInbox();
          },
        )
        .subscribe();

    // Subscribe to users table presence updates
    _usersChannel?.unsubscribe();
    _usersChannel = SupabaseConfig.client
        .channel('public:users')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            final newUserData = payload.newRecord;
            if (newUserData['id'] != null) {
              final uid = newUserData['id'] as String;
              if (mounted) {
                setState(() {
                  _userCache[uid] = newUserData;
                  
                  // Update online status in sessions list
                  for (int i = 0; i < _sessions.length; i++) {
                    if (_sessions[i].otherUserId == uid) {
                      final isOnline = newUserData['is_available'] as bool? ?? newUserData['is_online'] as bool? ?? false;
                      _sessions[i] = ChatSession(
                        id: _sessions[i].id,
                        name: _sessions[i].name,
                        service: _sessions[i].service,
                        avatarColor: _sessions[i].avatarColor,
                        isOnline: isOnline,
                        unreadCount: _sessions[i].unreadCount,
                        messages: _sessions[i].messages,
                        otherUserId: _sessions[i].otherUserId,
                      );
                    }
                  }

                  // Update currently active session status if it's the same user
                  if (_currentSession != null && _currentSession!.otherUserId == uid) {
                    final isOnline = newUserData['is_available'] as bool? ?? newUserData['is_online'] as bool? ?? false;
                    _currentSession = ChatSession(
                      id: _currentSession!.id,
                      name: _currentSession!.name,
                      service: _currentSession!.service,
                      avatarColor: _currentSession!.avatarColor,
                      isOnline: isOnline,
                      unreadCount: _currentSession!.unreadCount,
                      messages: _currentSession!.messages,
                      otherUserId: _currentSession!.otherUserId,
                    );
                  }
                });
              }
            }
          },
        )
        .subscribe();
  }

  void _loadCurrentSession() {
    if (widget.jobId != null && widget.jobId!.isNotEmpty) {
      final existingIdx = _sessions.indexWhere((s) => s.id == widget.jobId);
      if (existingIdx != -1) {
        setState(() {
          _currentSession = _sessions[existingIdx];
        });
        _subscribeToCurrentSessionMessages(widget.jobId!);
      } else {
        _fetchSingleSession(widget.jobId!);
      }
    } else {
      setState(() {
        _currentSession = null;
      });
      _messagesSubscription?.cancel();
    }
  }

  Future<void> _fetchSingleSession(String jobId) async {
    try {
      final jobResponse = await SupabaseConfig.client
          .from('jobs')
          .select('*, employer:users!employer_id(id, name), worker:users!worker_id(id, name)')
          .eq('id', jobId)
          .maybeSingle();

      if (jobResponse != null && mounted) {
        final otherUser = _isWorker ? jobResponse['employer'] : jobResponse['worker'];
        final otherName = otherUser != null ? (otherUser['name'] as String? ?? 'Jugaad Expert') : 'Jugaad Expert';
        final otherUserId = otherUser != null ? (otherUser['id'] as String? ?? '') : '';
        final skill = jobResponse['skill_required'] as String? ?? 'Service';
        final avatarColor = _getServiceColor(skill);

        final newSess = ChatSession(
          id: jobId,
          name: otherName,
          service: skill,
          avatarColor: avatarColor,
          isOnline: true,
          messages: [],
          otherUserId: otherUserId,
        );

        setState(() {
          _sessions.insert(0, newSess);
          _currentSession = newSess;
        });

        _subscribeToCurrentSessionMessages(jobId);
      }
    } catch (e) {
      print('[ChatScreen] Error fetching single session: $e');
    }
  }

  Future<void> _markMessagesAsRead(String jobId) async {
    if (_currentUid == null) return;
    try {
      await SupabaseConfig.client
          .from('messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('job_id', jobId)
          .neq('sender_id', _currentUid!)
          .isFilter('read_at', null);
    } catch (e) {
      print('[ChatScreen] Error marking messages as read: $e');
    }
  }

  void _onMessageTextChanged(String val) {
    if (_currentSession == null || _currentUid == null) return;
    final currentlyTyping = val.trim().isNotEmpty;
    if (currentlyTyping != _isMeTyping) {
      _isMeTyping = currentlyTyping;
      _updateTypingStatus(currentlyTyping);
    }

    _typingTimer?.cancel();
    if (currentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 4), () {
        if (_isMeTyping) {
          _isMeTyping = false;
          _updateTypingStatus(false);
        }
      });
    }
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (_currentSession == null || _currentUid == null) return;
    try {
      await SupabaseConfig.client.from('typing_states').upsert({
        'job_id': _currentSession!.id,
        'user_id': _currentUid!,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('[ChatScreen] Error updating typing status: $e');
    }
  }

  void _subscribeToCurrentSessionMessages(String jobId) {
    _messagesSubscription?.cancel();
    _typingChannel?.unsubscribe();

    setState(() {
      _otherUserIsTyping = false;
    });

    _markMessagesAsRead(jobId);

    final otherUserId = _currentSession!.otherUserId;

    _messagesSubscription = SupabaseService()
        .jobMessagesStream(jobId)
        .listen((msgsData) {
          if (!mounted || _currentSession == null || _currentSession!.id != jobId) return;

          final msgs = msgsData.map<ChatMessage>((m) {
            return ChatMessage(
              id: m['id'] as String,
              text: m['text'] as String? ?? '',
              isMe: m['sender_id'] == _currentUid,
              timestamp: DateTime.parse(m['created_at'] as String).toLocal(),
              readAt: m['read_at'] != null ? DateTime.parse(m['read_at'] as String).toLocal() : null,
            );
          }).toList();

          final hasUnread = msgs.any((m) => !m.isMe && m.readAt == null);
          if (hasUnread) {
            _markMessagesAsRead(jobId);
          }

          setState(() {
            _currentSession!.messages.clear();
            _currentSession!.messages.addAll(msgs);
          });
          _scrollToBottom(delayed: true);
        });

    if (otherUserId.isNotEmpty) {
      _typingChannel = SupabaseConfig.client
          .channel('public:typing_states')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'typing_states',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'job_id',
              value: jobId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord['user_id'] == otherUserId) {
                final isTyping = newRecord['is_typing'] as bool? ?? false;
                if (mounted) {
                  setState(() {
                    _otherUserIsTyping = isTyping;
                  });
                }
              }
            },
          )
          .subscribe();
    }
  }

  Color _getServiceColor(String skill) {
    switch (skill.toLowerCase()) {
      case 'electrician':
        return const Color(0xFFEAB308);
      case 'plumber':
        return const Color(0xFF2563EB);
      case 'laptop_repair':
        return const Color(0xFF16A34A);
      case 'phone_repair':
        return const Color(0xFFEC4899);
      case 'carpenter':
        return const Color(0xFF8B5CF6);
      case 'painter':
        return const Color(0xFFF97316);
      default:
        return AppColors.primary;
    }
  }

  void _scrollToBottom({bool delayed = false}) {
    if (delayed) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentSession == null || _currentUid == null) return;

    _messageController.clear();
    HapticFeedback.lightImpact();

    if (_isMeTyping) {
      _isMeTyping = false;
      _updateTypingStatus(false);
    }

    try {
      await SupabaseService().sendMessage(
        jobId: _currentSession!.id,
        senderId: _currentUid!,
        text: text,
      );
      _scrollToBottom(delayed: true);
    } catch (e) {
      print('[ChatScreen] Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentSession != null 
              ? _buildChatDetailView() 
              : (_isLoading ? _buildLoadingView() : _buildChatListView()),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  // ─── CHAT LIST VIEW (INBOX) ────────────────────────────────────────────────
  Widget _buildChatListView() {
    final filteredSessions = _sessions.where((session) {
      final query = _searchQuery.toLowerCase();
      return session.name.toLowerCase().contains(query) ||
             session.service.toLowerCase().contains(query) ||
             (session.lastMessage?.text.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Text(
            'Chats',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search chats or services...',
                hintStyle: GoogleFonts.dmSans(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Chat List
        Expanded(
          child: filteredSessions.isEmpty
              ? _buildEmptyInbox()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredSessions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    final lastMsg = session.lastMessage;
                    final initials = session.name.isNotEmpty ? session.name.substring(0, 1).toUpperCase() : 'J';

                    // Relative Time Formatter
                    String timeStr = '';
                    if (lastMsg != null) {
                      final diff = DateTime.now().difference(lastMsg.timestamp);
                      if (diff.inMinutes < 1) {
                        timeStr = 'Now';
                      } else if (diff.inHours < 1) {
                        timeStr = '${diff.inMinutes}m ago';
                      } else if (diff.inDays < 1) {
                        timeStr = '${lastMsg.timestamp.hour.toString().padLeft(2, '0')}:${lastMsg.timestamp.minute.toString().padLeft(2, '0')}';
                      } else {
                        timeStr = 'Yesterday';
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (_isWorker) {
                          context.go('/worker/chat?job_id=${session.id}');
                        } else {
                          context.go('/user/chat/${session.id}');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEFF3F8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: session.avatarColor.withValues(alpha: 0.12),
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.dmSans(
                                      color: session.avatarColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                if (session.isOnline)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),

                            // Name & Msg snippet
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          session.name,
                                          style: GoogleFonts.syne(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeStr,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    session.service.toUpperCase(),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: session.avatarColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lastMsg?.text ?? 'No messages yet.',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            color: session.unreadCount > 0
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF64748B),
                                            fontWeight: session.unreadCount > 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (session.unreadCount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${session.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: (index * 50).ms).fadeIn().slideY(begin: 0.1, end: 0);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyInbox() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: Color(0xFF94A3B8),
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Active Chats',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your conversation threads with service experts will appear here once a booking is assigned.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ─── CHAT CONVERSATION VIEW (THREAD) ───────────────────────────────────────
  Widget _buildChatDetailView() {
    final session = _currentSession!;
    final initials = session.name.isNotEmpty ? session.name.substring(0, 1).toUpperCase() : 'J';

    return Column(
      children: [
        // Premium AppBar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border(bottom: BorderSide(color: Color(0xFFEFF3F8))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (_isWorker) {
                    context.go('/worker/active?job_id=${session.id}');
                  } else {
                    context.go('/user/chat');
                  }
                },
              ),
              const SizedBox(width: 4),

              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: session.avatarColor.withValues(alpha: 0.12),
                    child: Text(
                      initials,
                      style: GoogleFonts.dmSans(
                        color: session.avatarColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (session.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.0),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      session.name,
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          session.service,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: session.avatarColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCBD5E1))),
                        const SizedBox(width: 6),
                        Text(
                          session.isOnline ? 'Online' : 'Offline',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: session.isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action shortcuts (Call worker)
              IconButton(
                icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 22),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Calling ${session.name}...'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Message Thread
        Expanded(
          child: Container(
            color: const Color(0xFFF3F6FA),
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 48), // Bottom padding for floating typing alert
                  itemCount: session.messages.length,
                  itemBuilder: (context, index) {
                    final msg = session.messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
                if (_otherUserIsTyping)
                  Positioned(
                    bottom: 8,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${session.name} is typing',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 1200.ms),
                  ),
              ],
            ),
          ),
        ),

        // Bottom Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
            border: Border(top: BorderSide(color: Color(0xFFEFF3F8))),
          ),
          child: Row(
            children: [
              // Photo attachment icon
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Camera access is not configured for this device.'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF64748B), size: 18),
                ),
              ),
              const SizedBox(width: 12),

              // Text Field Container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onMessageTextChanged,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Send button
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    // Formatting bubble corners based on sender
    final userCorners = const BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomRight: Radius.circular(2),
    );

    final senderCorners = const BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(2),
      topRight: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isMe ? AppColors.primary : Colors.white,
          borderRadius: msg.isMe ? userCorners : senderCorners,
          border: msg.isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.text,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: msg.isMe ? Colors.white : const Color(0xFF1E293B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    color: msg.isMe ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF94A3B8),
                  ),
                ),
                if (msg.isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.readAt != null ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 11,
                    color: msg.readAt != null ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
  }
}
