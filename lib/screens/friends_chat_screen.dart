import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/festival_models.dart';
import '../services/app_state.dart';

class FriendsChatScreen extends StatefulWidget {
  const FriendsChatScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  State<FriendsChatScreen> createState() => _FriendsChatScreenState();
}

class _FriendsChatScreenState extends State<FriendsChatScreen> {
  bool _showGroupsTab = false;
  final _addFriendCtrl = TextEditingController();

  @override
  void dispose() {
    _addFriendCtrl.dispose();
    super.dispose();
  }

  // Share My QR Code Modal
  void _openShareMyQrDialog() {
    final appState = widget.appState;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFFFF2E93)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'My Festival Buddy QR',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF7C3AED),
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    size: 160,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appState.visitorUsername,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              appState.visitorName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Let a friend scan this QR code or enter your unique username to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: appState.visitorUsername));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Copied username ${appState.visitorUsername} to clipboard!',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Username'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // Scan Friend's QR Code Modal
  void _openScanQrSheet() {
    final qrHandleCtrl = TextEditingController(text: '@lucas_ehv_92');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF00E5FF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scan Friend QR Code',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Camera Viewfinder Simulation
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0B18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF00E5FF),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 135,
                    height: 135,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFF2E93),
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 76,
                      color: Colors.white54,
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Align friend QR inside frame',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: qrHandleCtrl,
              decoration: const InputDecoration(
                labelText: 'Detected QR Username',
                prefixIcon: Icon(Icons.qr_code_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E93),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () {
                  final scanned = qrHandleCtrl.text.trim().isEmpty
                      ? '@lucas_ehv_92'
                      : qrHandleCtrl.text.trim();
                  final added =
                      widget.appState.addCustomFriendByUsername(scanned);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Scanned QR & added ${added.username} to your Community!',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text(
                  'Scan & Add Friend Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDirectChatSheet(BuddyFriend friend) {
    final msgCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final messages = widget.appState.getDirectMessages(friend.id);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
                    leading: CircleAvatar(
                      backgroundColor: friend.avatarColor,
                      child: Text(
                        friend.name.characters.first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${friend.name} (${friend.username})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      friend.sharedLocation ?? friend.statusText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: Color(0xFF00E5FF),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Send your live festival pin:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            widget.appState.sendDirectMessage(
                              friendId: friend.id,
                              text: 'Here is my live festival location!',
                              sharedLocationLabel:
                                  '📍 Live Pin: Kinetic Mainstage (Eindhoven)',
                            );
                            setSheetState(() {});
                          },
                          icon:
                              const Icon(Icons.share_location_rounded, size: 16),
                          label: const Text(
                            'Share Location',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        return _buildChatBubble(context, m);
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: msgCtrl,
                              decoration: InputDecoration(
                                hintText: 'Message ${friend.name}...',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFF2E93),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              if (msgCtrl.text.trim().isEmpty) return;
                              widget.appState.sendDirectMessage(
                                friendId: friend.id,
                                text: msgCtrl.text,
                              );
                              msgCtrl.clear();
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openGroupChatSheet(FriendGroup group) {
    final msgCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.80,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${group.memberIds.length + 1} members • Live Location Group',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: const Color(0xFFFF2E93).withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Color(0xFFFF2E93),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Drop your live location to the group:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            widget.appState.sendGroupMessage(
                              groupId: group.id,
                              text: 'Meet me here!',
                              sharedLocationLabel:
                                  '📍 Group Live Pin: Neon Forest Stage (Eindhoven)',
                            );
                            setSheetState(() {});
                          },
                          icon:
                              const Icon(Icons.share_location_rounded, size: 16),
                          label: const Text(
                            'Share Group Pin',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: group.messages.length,
                      itemBuilder: (context, index) {
                        return _buildChatBubble(context, group.messages[index]);
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: msgCtrl,
                              decoration: InputDecoration(
                                hintText: 'Message ${group.name}...',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFF2E93),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              if (msgCtrl.text.trim().isEmpty) return;
                              widget.appState.sendGroupMessage(
                                groupId: group.id,
                                text: msgCtrl.text,
                              );
                              msgCtrl.clear();
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCreateGroupDialog() {
    final groupNameCtrl = TextEditingController();
    final selectedMemberIds = <String>{
      for (final f in widget.appState.myFriends.take(2)) f.id,
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Festival Friend Group',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: groupNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group Name (e.g., Eindhoven Rave Crew)',
                  prefixIcon: Icon(Icons.groups_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Select Friends to Add:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.appState.myFriends.map((friend) {
                  final isSel = selectedMemberIds.contains(friend.id);
                  return FilterChip(
                    selected: isSel,
                    label: Text(friend.name),
                    onSelected: (_) {
                      setModalState(() {
                        if (isSel) {
                          selectedMemberIds.remove(friend.id);
                        } else {
                          selectedMemberIds.add(friend.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2E93),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final grp = widget.appState.createFriendGroup(
                      groupName: groupNameCtrl.text.isEmpty
                          ? 'Weekend Squad 🔥'
                          : groupNameCtrl.text,
                      memberIds: selectedMemberIds.toList(),
                    );
                    Navigator.pop(ctx);
                    setState(() => _showGroupsTab = true);
                    _openGroupChatSheet(grp);
                  },
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      'Create Group & Start Sharing Locations',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, ChatMessage m) {
    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 290),
        decoration: BoxDecoration(
          gradient: m.isMe
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                )
              : null,
          color: m.isMe
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
            if (m.text.isNotEmpty)
              Text(
                m.text,
                style: TextStyle(
                  color: m.isMe ? Colors.white : null,
                  fontSize: 13.5,
                ),
              ),
            if (m.sharedLocationLabel != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF00E5FF),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        m.sharedLocationLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
        // Top Card: My Unique Assigned Username + Scan QR & Share QR Buttons
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7C3AED).withValues(alpha: 0.25),
                const Color(0xFFFF2E93).withValues(alpha: 0.20),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.alternate_email_rounded,
                    color: Color(0xFF00E5FF),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'My Unique Username: ${appState.visitorUsername}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openScanQrSheet,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text(
                        'Scan QR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2E93),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openShareMyQrDialog,
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text(
                        'Share QR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Toggle: Friends (1-on-1) | Groups (Squads)
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showGroupsTab = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: !_showGroupsTab
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        'Friends (${appState.myFriends.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: !_showGroupsTab ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showGroupsTab = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: _showGroupsTab
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        'Groups (${appState.friendGroups.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _showGroupsTab ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (!_showGroupsTab) ...[
          // Add Friend by Unique @username Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addFriendCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add friend by unique @username...',
                    prefixIcon: const Icon(Icons.person_add_alt_1_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E93),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (_addFriendCtrl.text.trim().isEmpty) return;
                  final added = appState
                      .addCustomFriendByUsername(_addFriendCtrl.text);
                  _addFriendCtrl.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Added ${added.username} to your Community!',
                      ),
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Text(
            'My Community Friends (Tap to Chat & Share Location)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...appState.myFriends.map(
            (friend) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _openDirectChatSheet(friend),
                leading: CircleAvatar(
                  backgroundColor: friend.avatarColor,
                  child: Text(
                    friend.name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  '${friend.name} (${friend.username})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '📍 ${friend.sharedLocation ?? friend.statusText}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                trailing: IconButton.filledTonal(
                  onPressed: () => _openDirectChatSheet(friend),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                ),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF2E93),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _openCreateGroupDialog,
              icon: const Icon(Icons.group_add_rounded),
              label: const Text(
                'Create New Friend Group',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...appState.friendGroups.map(
            (group) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                onTap: () => _openGroupChatSheet(group),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.groups_rounded, color: Colors.white),
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '${group.memberIds.length + 1} members • Tap to chat & share group location',
                  style: const TextStyle(fontSize: 12.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
