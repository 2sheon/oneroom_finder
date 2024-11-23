import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 이미지 선택
import 'dart:io'; // 이미지 파일 관련
import 'post_service.dart'; // PostService import

class PostCreateScreen extends StatefulWidget {
  final PostService postService;

  const PostCreateScreen({super.key, required this.postService});

  @override
  _PostCreateScreenState createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String selectedTag = '삽니다';
  final List<String> tags = ['삽니다', '팝니다'];
  File? selectedImage; // 선택된 이미지 파일

  String? type = '월세'; // 거래 유형
  String? title = '원룸'; // 타입 선택 (원룸, 투룸, 쓰리룸)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 작성'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '태그 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: selectedTag,
              items: tags.map((tag) {
                return DropdownMenuItem(
                  value: tag,
                  child: Text(tag),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedTag = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 타입 선택 (원룸, 투룸, 쓰리룸)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '타입 선택',
                border: OutlineInputBorder(),
              ),
              value: title,
              items: ['원룸', '투룸', '쓰리룸']
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  title = value;
                });
              },
            ),
            const SizedBox(height: 10),

            // 거래 유형 (월세, 전세)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '거래 유형',
                border: OutlineInputBorder(),
              ),
              value: type,
              items: ['월세', '전세']
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  type = value;
                });
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final pickedFile =
                    await ImagePicker().pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  setState(() {
                    selectedImage = File(pickedFile.path);
                  });
                }
              },
              child: const Text('사진 추가'),
            ),
            if (selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Image.file(selectedImage!),
              ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // 게시글 작성
                  widget.postService.createPost(
                    context,
                    _titleController.text.trim(),
                    _contentController.text.trim(),
                    tag: selectedTag,
                    image: selectedImage, // 이미지 전달
                    type: type, // 거래 유형 전달
                    roomType: title, // 타입 선택 전달
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('작성하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
