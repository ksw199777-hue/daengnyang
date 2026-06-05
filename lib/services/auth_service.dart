import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 유저
  User? get currentUser => _auth.currentUser;

  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 구글 로그인
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        await _saveUserToFirestore(user.uid, user.email ?? '', user.photoURL);
      }

      return user;
    } catch (e) {
      print('구글 로그인 에러: $e');
      return null;
    }
  }

  // 카카오 로그인
  Future<User?> signInWithKakao() async {
    try {
      kakao.OAuthToken token;

      if (await kakao.isKakaoTalkInstalled()) {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      final kakaoUser = await kakao.UserApi.instance.me();
      final email =
          kakaoUser.kakaoAccount?.email ?? '${kakaoUser.id}@kakao.com';
      final profileImage = kakaoUser.kakaoAccount?.profile?.profileImageUrl;

      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: 'kakao_${kakaoUser.id}',
        );
      } catch (e) {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: 'kakao_${kakaoUser.id}',
        );
      }

      final User? user = userCredential.user;
      if (user != null) {
        await _saveUserToFirestore(user.uid, email, profileImage);
      }

      return user;
    } catch (e) {
      print('카카오 로그인 에러: $e');
      return null;
    }
  }

  // Firestore에 유저 저장
  Future<void> _saveUserToFirestore(
    String uid,
    String email,
    String? profileImage,
  ) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      // 첫 가입
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'nickname': null,
        'profileImage': profileImage,
        'subscriptionType': 'free',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 재로그인 - 이메일, 프로필만 업데이트
      await _firestore.collection('users').doc(uid).update({
        'email': email,
        'profileImage': profileImage,
      });
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    try {
      await kakao.UserApi.instance.logout();
    } catch (e) {
      print('카카오 로그아웃 에러: $e');
    }
  }
}
