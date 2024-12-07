import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneroom_finder/post/room_details_screen.dart';

class LikePostDialog extends StatelessWidget {
  final String userId;
  const LikePostDialog({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    return AlertDialog(
      title: const Text('관심있는 방'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(userId).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Center(child: Text('사용자 데이터를 불러올 수 없습니다.'));
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> likedPosts = userData['likedPosts'] ?? [];

            if (likedPosts.isEmpty) {
              return const Center(child: Text('좋아요한 게시글이 없습니다.'));
            }

            return _buildPostList(likedPosts);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildPostList(List<dynamic> likedPosts) {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    // 배열을 10개씩 나눔
    List<List<dynamic>> chunkedPostIds = [];
    for (var i = 0; i < likedPosts.length; i += 10) {
      chunkedPostIds.add(likedPosts.sublist(
          i, i + 10 > likedPosts.length ? likedPosts.length : i + 10));
    }

    return ListView.builder(
      itemCount: chunkedPostIds.length,
      itemBuilder: (context, index) {
        final List<dynamic> postIdsChunk = chunkedPostIds[index];
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('posts')
              .where(FieldPath.documentId, whereIn: postIdsChunk)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('게시글이 없습니다.'));
            }

            final posts = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final Map<String, dynamic> postData =
                    posts[index].data() as Map<String, dynamic>;
                final String postId = posts[index].id;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12.0),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RoomDetailsScreen(postId: postId),
                        ),
                      );
                    },
                    leading: postData['imageUrl'] != null &&
                            postData['imageUrl'].isNotEmpty
                        ? Image.network(
                            postData['imageUrl'],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(
                            width: 100,
                            height: 100,
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (postData['tag'] != null &&
                            postData['tag'].isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              postData['tag'],
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          postData['title'] ?? '제목 없음',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${postData['location'] ?? '위치 없음'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          postData['content'] ?? '내용 없음',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '후기 ${postData['review'] ?? 0}개',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}