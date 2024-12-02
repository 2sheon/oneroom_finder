import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final AuthService authService = AuthService(); // AuthService 인스턴스 생성

  Future<void> createPost(
    BuildContext context,
    String roominfo,
    String content, {
    required String tag,
    Uint8List? image,
    String? type, // 거래 유형
    String? roomType, // 타입 선택 (원룸, 투룸, 쓰리룸)
  }) async {
    if (roominfo.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요.')),
      );
      return;
    }

    String? imageUrl;
    final currentUser = await authService.isUserLoggedIn();
    if (!currentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인된 사용자가 없습니다.')),
      );
      return;
    }
    final String authorId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (authorId.isEmpty) {
      // UID가 null일 때 처리
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 ID를 찾을 수 없습니다.')),
      );
      return;
    }

    // 이미지가 선택되었으면 Firebase Storage에 업로드
    if (image != null) {
      // Firebase Storage에 업로드할 파일 경로 지정
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('post_images/${DateTime.now().millisecondsSinceEpoch}');

      // 이미지를 Firebase Storage에 업로드
      final uploadTask = storageRef.putData(image);
      await uploadTask.whenComplete(() async {
        // 업로드 완료 후 이미지 URL 가져오기
        imageUrl = await storageRef.getDownloadURL();
      });
    }

    // Firestore에 게시글 저장
    try {
      await firestore.collection('posts').add({
        'tag': tag,
        'title': roominfo,
        'content': content,
        'likes': 0,
        'review': 0,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'authorId': authorId, // authorId 추가
        'createdAt': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl, // 이미지 URL 저장 (이미지가 없으면 null)
        'type': type, // 거래 유형 저장
        'roomType': roomType, // 타입 저장
        'createAt': Timestamp.now(), // createAt이 없으면 현재 시간으로 설정
      });

      // 성공적으로 게시글 작성 후 UI 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 작성되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('게시글 작성 중 오류 발생: $e')),
      );
      // 에러를 추가로 로그로 출력하여 문제를 더 잘 파악할 수 있도록 하기
      print("Error creating post: $e");
    }
  }

  // 게시글 조회 기능
  Stream<QuerySnapshot> getPosts() {
    return firestore
        .collection('posts')
        .orderBy('createAt', descending: true)
        .snapshots();
  }

  // 게시글 상세 조회 기능
  Future<Map<String, dynamic>?> fetchPostDetails(String postId) async {
    try {
      final postDoc = await firestore.collection('posts').doc(postId).get();

      if (!postDoc.exists) {
        throw Exception('게시글을 찾을 수 없습니다.');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final authorId = postData['authorId']; // authorId 포함
      final createAt = postData['createAt'] ??
          Timestamp.now(); // Firestore에서 createAt 값 가져오기, 없으면 현재 시간 사용

      // 반환할 데이터에 authorId 포함
      return {
        'title': postData['title'],
        'content': postData['content'],
        'likes': postData['likes'],
        'review': postData['review'],
        'authorId': authorId, // authorId 추가
        'image': postData['image'],
        'type': postData['type'],
        'roomType': postData['roomType'],
        'createAt': createAt, // createAt 필드 추가
      };
    } catch (e) {
      throw Exception('게시글 상세 조회 중 오류 발생: $e');
    }
  }

  // 게시글 수정 기능
  Future<void> updatePost(String postId, String title, String content,
      String? type, String? roomType, dynamic image) async {
    try {
      DocumentReference postRef = firestore.collection('posts').doc(postId);

      // 해당 postId가 있는지 확인
      DocumentSnapshot postSnapshot = await postRef.get();
      if (!postSnapshot.exists) {
        throw '게시글이 존재하지 않습니다.';
      }
      String? imageUrl;
      if (image != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = storage.ref('post_images/$fileName');

        if (image is File) {
          // 모바일에서 File 객체로 업로드
          await ref.putFile(image);
        } else if (image is Uint8List) {
          // 웹에서 Uint8List로 업로드
          await ref.putData(image);
        }

        imageUrl = await ref.getDownloadURL();
      }

      // 게시글 업데이트
      final updateData = {
        'title': title,
        'content': content,
        'updateAt': FieldValue.serverTimestamp(),
        'type': type,
        'roomType': roomType,
      };
      if (imageUrl != null) {
        updateData['image'] = imageUrl; // 새 이미지 URL 추가
      }

      await postRef.update(updateData);
    } catch (e) {
      throw '게시글 수정 중 오류 발생: $e';
    }
  }

  // 게시글 삭제 기능
  Future<void> deletePost(BuildContext context, String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인 상태를 확인해주세요.');
      }

      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        throw Exception('게시글이 존재하지 않습니다.');
      }

      final postUserId = postDoc['userId'] as String? ?? '';

      if (currentUser.uid != postUserId) {
        throw Exception('삭제 권한이 없습니다.');
      }

      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('게시글 삭제 중 오류 발생: $e')),
      );
    }
  }

  // 좋아요 기능
  Future<void> incrementLikes(String postId) async {
    try {
      final postRef = firestore.collection('posts').doc(postId);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);

        if (!snapshot.exists) return;

        final currentLikes = snapshot.data()?['likes'] ?? 0;
        transaction.update(postRef, {'likes': currentLikes + 1});
      });
    } catch (e) {
      debugPrint('Error updating likes: $e');
    }
  }

  //댓글 횟수
  Future<void> incrementComments(String postId) async {
    try {
      final postRef = firestore.collection('posts').doc(postId);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);

        if (!snapshot.exists) return;

        final currentComments = snapshot.data()?['review'] ?? 0;
        transaction.update(postRef, {'review': currentComments + 1});
      });
    } catch (e) {
      debugPrint('Error updating comments: $e');
    }
  }

  // 좋아요 토글 (계정당 1번 제한)
  Future<void> toggleLike(
      String postId, String userId, BuildContext context) async {
    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      final userLikeRef = postRef.collection('likes').doc(userId);

      final userLikeSnapshot = await userLikeRef.get();

      if (userLikeSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 좋아요를 눌렀습니다.')),
        );
        return; // 이미 좋아요를 눌렀으면, 함수 종료
      } else {
        // 좋아요 추가
        await userLikeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await postRef.update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 로그인 여부 체크
  Future<bool> isUserLoggedIn() async {
    final currentUser = _auth.currentUser;
    return currentUser != null;
  }

  // 로그인한 사용자 UID 반환
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  // 사용자 로그인
  Future<UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print('로그인 실패: $e');
      return null;
    }
  }

  // 사용자 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 현재 로그인한 사용자 정보 반환
  User? get currentUser {
    return _auth.currentUser;
  }
}
