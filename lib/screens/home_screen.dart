import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loginStatue = false; // 로그인 상태
  final googleSignIn = GoogleSignIn.standard(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );
  String message = "구글 드라이브에 업로드할 파일을 첨부하십시오.";
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _loginStatue = googleSignIn.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset("assets/images/99DC99425AD5BD9D2C.png", width: 150),
            ),
            const SizedBox(height: 10),
            Text("구글 로그인 상태: ${_loginStatue ? "로그인됨" : "로그아웃됨"}"),
            const SizedBox(height: 10),
            _loginStatue ? _buildGoogleSignOutButton() : _buildGoogleSignInButton(),
            if (_loginStatue) _buildFileUploadWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      child: ElevatedButton(
        style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith((states) => Colors.white)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/google.png", width: 30, height: 30),
              const SizedBox(width: 10),
              const Text("구글 로그인", style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        onPressed: _signIn,
      ),
    );
  }

  Widget _buildGoogleSignOutButton() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      child: ElevatedButton(
        style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith((states) => Colors.white)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/google.png", width: 30, height: 30),
              const SizedBox(width: 10),
              const Text("구글 로그아웃", style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              const Icon(Icons.logout, color: Colors.black, size: 20),
            ],
          ),
        ),
        onPressed: _signOut,
      ),
    );
  }

  Widget _buildFileUploadWidget() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Text(message),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles();

                if (result == null) return;

                setState(() {
                  _selectedFile = File(result.files.first.path!);
                  message = result.files.first.name;
                });
              },
              child: const Text("파일 선택"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: _selectedFile == null ? Colors.grey : Colors.blue),
              onPressed: () async {
                if (_selectedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("파일 첨부가 안되어 있어 업로드 실패하였습니다.", textAlign: TextAlign.center)));
                  return;
                }

                await upload(_selectedFile!);

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("성공적으로 업로드되었습니다.", textAlign: TextAlign.center)));
                setState(() {
                  _selectedFile = null;
                  message = "구글 드라이브에 업로드할 파일을 첨부하십시오.";
                });
              },
              child: const Text("업로드"),
            ),
          ],
        )
      ],
    );
  }

  upload(File file) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return;

    final driveFile = new drive.File();
    driveFile.name = message;
    driveFile.modifiedTime = DateTime.now().toUtc();

    await driveApi.files.create(driveFile, uploadMedia: drive.Media(file.openRead(), file.lengthSync()));
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final googleUser = await googleSignIn.signIn();
    final headers = await googleUser?.authHeaders;
    if (headers == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("로그인 필요합니다.")));
      return null;
    }

    final client = GoogleAuthClient(headers);
    final driveApi = drive.DriveApi(client);
    return driveApi;
  }

  Future<void> _signIn() async {
    final googleUser = await googleSignIn.signIn();

    try {
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential loginUser = await FirebaseAuth.instance.signInWithCredential(credential);
        assert(loginUser.user?.uid == FirebaseAuth.instance.currentUser?.uid);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("성공적으로 로그인되었습니다.", textAlign: TextAlign.center)));

        setState(() {
          _loginStatue = true;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    googleSignIn.signOut();
    setState(() {
      _loginStatue = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("성공적으로 로그아웃 되었습니다.", textAlign: TextAlign.center)));
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _client = new http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
